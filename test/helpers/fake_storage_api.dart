import 'dart:io';
import 'dart:typed_data';

import 'package:pet_passport/features/sync/data/storage_api.dart';

/// In-memory [StorageApi] for tests. Objects are keyed by
/// `"$bucket/$key"` in a single map so tests can seed remote state
/// directly via [seed] before exercising a download path.
class FakeStorageApi implements StorageApi {
  final Map<String, Uint8List> objects = {};
  final List<StorageResult> _forcedUploads = [];
  final List<StorageResult> _forcedDeletes = [];
  final List<StorageDownloadResult> _forcedDownloads = [];
  final List<FakeUploadCall> uploadCalls = [];
  final List<FakeDeleteCall> deleteCalls = [];

  void queueUploadResult(StorageResult r) => _forcedUploads.add(r);
  void queueUploadRetryable([String reason = 'fake retryable']) =>
      queueUploadResult(StorageRetryable(reason));
  void queueUploadTerminal([String reason = 'fake terminal']) =>
      queueUploadResult(StorageTerminal(reason));

  void queueDeleteResult(StorageResult r) => _forcedDeletes.add(r);
  void queueDownloadResult(StorageDownloadResult r) =>
      _forcedDownloads.add(r);

  void seed(String bucket, String key, Uint8List bytes) {
    objects['$bucket/$key'] = bytes;
  }

  Uint8List? find(String bucket, String key) => objects['$bucket/$key'];

  @override
  Future<StorageResult> uploadObject({
    required String bucket,
    required String key,
    required File file,
    String? mimeType,
  }) async {
    uploadCalls.add(FakeUploadCall(bucket, key, file.path, mimeType));
    if (_forcedUploads.isNotEmpty) return _forcedUploads.removeAt(0);
    objects['$bucket/$key'] = await file.readAsBytes();
    return const StorageOk();
  }

  @override
  Future<StorageResult> deleteObject({
    required String bucket,
    required String key,
  }) async {
    deleteCalls.add(FakeDeleteCall(bucket, key));
    if (_forcedDeletes.isNotEmpty) return _forcedDeletes.removeAt(0);
    objects.remove('$bucket/$key');
    return const StorageOk();
  }

  @override
  Future<StorageDownloadResult> downloadObject({
    required String bucket,
    required String key,
  }) async {
    if (_forcedDownloads.isNotEmpty) return _forcedDownloads.removeAt(0);
    final bytes = objects['$bucket/$key'];
    if (bytes == null) {
      return const StorageDownloadTerminal('http 404: not found');
    }
    return StorageDownloadOk(bytes);
  }
}

class FakeUploadCall {
  FakeUploadCall(this.bucket, this.key, this.localPath, this.mimeType);
  final String bucket;
  final String key;
  final String localPath;
  final String? mimeType;
}

class FakeDeleteCall {
  FakeDeleteCall(this.bucket, this.key);
  final String bucket;
  final String key;
}
