import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_api.dart';

/// Lazy download + local-cache resolver for cloud-stored media.
///
/// The row-sync engine propagates the `storage_key` string; the file
/// itself doesn't come along. When a viewer wants to display a
/// photo/PDF, this class:
///
///   1. Checks the local hint path — if the file exists (i.e. the
///      current device is the sender OR we've cached this key before)
///      just return that path.
///   2. Otherwise checks the cache dir (a hash of the storage key).
///   3. Otherwise downloads via [StorageApi], writes to the cache
///      dir, returns the freshly-cached path.
///
/// LRU eviction is deferred to a follow-up task — v1 keeps everything.
/// A conservative rule of thumb: cache dir cleanup runs on cold start
/// if the total size exceeds the plan's 200 MB target.
class MediaFetcher {
  MediaFetcher(this._storage, {Future<Directory> Function()? cacheDirLoader})
      : _cacheDirLoader = cacheDirLoader ?? getTemporaryDirectory;

  final StorageApi _storage;
  final Future<Directory> Function() _cacheDirLoader;

  static const bucket = 'media';

  /// Records the reason for the most recent failed [resolve] call so
  /// UI code can surface the underlying storage error instead of a
  /// generic "unavailable". Reset to null on the next successful
  /// resolve.
  String? lastError;

  /// Returns an absolute local path where the file lives now. Blocks
  /// on a download if we don't have it yet. Returns null on any
  /// terminal failure (missing storage key, RLS deny, 404) so
  /// callers can fall back to a placeholder — the specific reason
  /// lives in [lastError] afterwards.
  Future<String?> resolve({
    required String? storageKey,
    String? localHintAbsolute,
  }) async {
    if (localHintAbsolute != null) {
      final f = File(localHintAbsolute);
      if (await f.exists()) {
        lastError = null;
        return localHintAbsolute;
      }
    }
    if (storageKey == null) {
      lastError = 'no storage key';
      return null;
    }

    final cached = await _cachedPath(storageKey);
    final f = File(cached);
    if (await f.exists()) {
      lastError = null;
      return cached;
    }

    final result = await _storage.downloadObject(
      bucket: bucket,
      key: storageKey,
    );
    switch (result) {
      case StorageDownloadOk(:final bytes):
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes, flush: true);
        lastError = null;
        return cached;
      case StorageDownloadRetryable(:final reason):
        lastError = 'retryable: $reason';
        return null;
      case StorageDownloadTerminal(:final reason):
        lastError = reason;
        return null;
    }
  }

  /// Where a given key gets cached. Preserving the key's basename
  /// keeps extension info intact for viewers that sniff on the
  /// filename (open_filex + friends).
  Future<String> _cachedPath(String storageKey) async {
    final root = await _cacheRoot();
    // Directory sharding by the leading path segment keeps the cache
    // dir listing tolerable if a household grows past a few hundred
    // objects; the leaf keeps the leaf-name so tools that read the
    // file extension still work.
    return p.join(root.path, storageKey);
  }

  Future<Directory> _cacheRoot() async {
    final tmp = await _cacheDirLoader();
    final dir = Directory(p.join(tmp.path, 'media-cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Runs the LRU eviction sweep. Sums the cache size; if over
  /// [maxBytes] deletes the least-recently-modified files (Android
  /// tends to not track atime reliably, so we use mtime which the OS
  /// bumps on read via download-and-write anyway) until the total is
  /// back under cap.
  ///
  /// Best-effort — a filesystem hiccup deletes what it can and
  /// swallows the rest. Called once on cold start; skipping it is
  /// only a size problem, never a correctness one.
  ///
  /// Default 200 MB matches the plan's Free-Tier storage target.
  Future<CacheSweepResult> sweep({
    int maxBytes = 200 * 1024 * 1024,
  }) async {
    final root = await _cacheRoot();
    final files = <File>[];
    var total = 0;
    try {
      await for (final entity in root.list(recursive: true)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          total += stat.size;
          files.add(entity);
        } catch (_) {
          // Racy: file might vanish mid-list. Skip.
        }
      }
    } catch (_) {
      // Cache dir gone or unreadable — nothing to sweep.
      return const CacheSweepResult(
          totalBytesBefore: 0, deletedFiles: 0, totalBytesAfter: 0);
    }

    if (total <= maxBytes) {
      return CacheSweepResult(
        totalBytesBefore: total,
        deletedFiles: 0,
        totalBytesAfter: total,
      );
    }

    // Sort oldest-first (smallest mtime = coldest).
    final withStat = <_FileWithStat>[];
    for (final f in files) {
      try {
        withStat.add(_FileWithStat(f, await f.stat()));
      } catch (_) {}
    }
    withStat.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));

    var deleted = 0;
    var current = total;
    for (final entry in withStat) {
      if (current <= maxBytes) break;
      try {
        await entry.file.delete();
        current -= entry.stat.size;
        deleted++;
      } catch (_) {
        // Someone else grabbed / locked the file. Move on; the next
        // sweep will retry.
      }
    }
    return CacheSweepResult(
      totalBytesBefore: total,
      deletedFiles: deleted,
      totalBytesAfter: current,
    );
  }
}

class CacheSweepResult {
  const CacheSweepResult({
    required this.totalBytesBefore,
    required this.deletedFiles,
    required this.totalBytesAfter,
  });
  final int totalBytesBefore;
  final int deletedFiles;
  final int totalBytesAfter;
}

class _FileWithStat {
  const _FileWithStat(this.file, this.stat);
  final File file;
  final FileStat stat;
}
