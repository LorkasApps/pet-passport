import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import 'media_outbox.dart';

/// Startup scan that pulls pre-M5 rows into the media outbox.
///
/// Every media-carrying row created before the M5 wiring landed has:
///   * a local `file_path` / `profile_photo_path` pointing at a real
///     file on this device
///   * no `storage_key` (the outbox never got the enqueue at write
///     time — it didn't exist yet)
///
/// Row-sync happily pushed those rows to the cloud with a null
/// storage_key, so peers see the metadata but can never download.
/// This class walks each media-carrying table once on start-up, and
/// enqueues an upload for any row that fits the pattern.
///
/// Idempotent: once the upload worker succeeds and writes the
/// storage_key back on the row, the WHERE clause drops it and
/// subsequent scans do nothing. Safe to call every start.
class MediaBackfiller {
  MediaBackfiller(this._db, this._media, this._outbox);

  final AppDatabase _db;
  final MediaService _media;
  final MediaOutbox _outbox;

  /// Pets carry the profile photo directly on the pets row (unique
  /// column names for path + storage-key) so it gets its own scanner.
  /// Every other surface follows the same nested-doc shape.
  static const _nested = <_NestedSpec>[
    _NestedSpec('pet_documents'),
    _NestedSpec('pet_passport_documents'),
    _NestedSpec('event_photos'),
    _NestedSpec('food_photos'),
    _NestedSpec('insurance_documents'),
    _NestedSpec('vaccination_documents'),
  ];

  Future<BackfillResult> backfill() async {
    var enqueued = 0;
    var missing = 0;

    final petsCount = await _backfillPets();
    enqueued += petsCount.enqueued;
    missing += petsCount.missingLocalFile;

    for (final spec in _nested) {
      final r = await _backfillNested(spec);
      enqueued += r.enqueued;
      missing += r.missingLocalFile;
    }
    return BackfillResult(enqueued: enqueued, missingLocalFile: missing);
  }

  Future<BackfillResult> _backfillPets() async {
    final rows = await _db.customSelect(
      'SELECT uuid, profile_photo_path, household_id '
      'FROM pets '
      "WHERE profile_photo_path IS NOT NULL AND profile_photo_path != '' "
      'AND profile_photo_storage_key IS NULL '
      'AND household_id IS NOT NULL '
      'AND deleted_at IS NULL',
    ).get();
    var enqueued = 0;
    var missing = 0;
    for (final r in rows) {
      final uuid = r.read<String>('uuid');
      final path = r.read<String>('profile_photo_path');
      final hid = r.read<String>('household_id');
      final abs = await _media.resolve(path);
      if (!await File(abs).exists()) {
        missing++;
        continue;
      }
      final ext = p.extension(path);
      await _outbox.enqueueUpload(
        entityTable: 'pets',
        entityUuid: uuid,
        localPath: abs,
        storageKey: 'household/$hid/pets/$uuid/profile$ext',
        mimeType: _guessMime(ext),
      );
      enqueued++;
    }
    return BackfillResult(enqueued: enqueued, missingLocalFile: missing);
  }

  Future<BackfillResult> _backfillNested(_NestedSpec spec) async {
    final rows = await _db.customSelect(
      'SELECT uuid, file_path, mime_type, household_id '
      'FROM ${spec.table} '
      "WHERE file_path IS NOT NULL AND file_path != '' "
      'AND storage_key IS NULL '
      'AND household_id IS NOT NULL '
      'AND deleted_at IS NULL',
    ).get();
    var enqueued = 0;
    var missing = 0;
    for (final r in rows) {
      final uuid = r.read<String>('uuid');
      final path = r.read<String>('file_path');
      final mime = r.read<String>('mime_type');
      final hid = r.read<String>('household_id');
      final abs = await _media.resolve(path);
      if (!await File(abs).exists()) {
        missing++;
        continue;
      }
      final ext = p.extension(path);
      await _outbox.enqueueUpload(
        entityTable: spec.table,
        entityUuid: uuid,
        localPath: abs,
        storageKey: 'household/$hid/${spec.table}/$uuid$ext',
        mimeType: mime,
      );
      enqueued++;
    }
    return BackfillResult(enqueued: enqueued, missingLocalFile: missing);
  }

  String? _guessMime(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
    }
    return null;
  }
}

class _NestedSpec {
  const _NestedSpec(this.table);
  final String table;
}

class BackfillResult {
  const BackfillResult({
    required this.enqueued,
    required this.missingLocalFile,
  });

  /// Rows that got a fresh upload enqueue.
  final int enqueued;

  /// Rows that had a file_path but no file at that path (peer-only
  /// copy that never landed on this device). Not an error — the
  /// eventual pull from the peer that DID upload it fills in the
  /// storage_key.
  final int missingLocalFile;
}
