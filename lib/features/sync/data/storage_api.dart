import 'dart:io';
import 'dart:typed_data';

/// Abstraction over Supabase Storage. The upload worker only ever
/// touches this interface; production wires it to
/// SupabaseStorageApi, tests wire it to FakeStorageApi.
///
/// Result variants mirror [CloudUpsertResult] semantics so the worker's
/// retry/backoff logic branches the same way (ok / retryable / terminal).
abstract class StorageApi {
  /// Upload a file to `bucket/key`. `mimeType` gets attached as the
  /// object's Content-Type — the storage bucket also enforces a
  /// mime allowlist server-side, so a mismatch surfaces as terminal.
  Future<StorageResult> uploadObject({
    required String bucket,
    required String key,
    required File file,
    String? mimeType,
  });

  /// Remove `bucket/key`. No-op if the object doesn't exist.
  Future<StorageResult> deleteObject({
    required String bucket,
    required String key,
  });

  /// Download `bucket/key` into memory. The media fetcher writes the
  /// bytes to a cache-dir file keyed by the object hash. Fetching to
  /// bytes rather than a File means we don't need a mutable "where
  /// should this live" arg at the API surface.
  Future<StorageDownloadResult> downloadObject({
    required String bucket,
    required String key,
  });
}

sealed class StorageResult {
  const StorageResult();
}

class StorageOk extends StorageResult {
  const StorageOk();
}

class StorageRetryable extends StorageResult {
  const StorageRetryable(this.reason);
  final String reason;
}

class StorageTerminal extends StorageResult {
  const StorageTerminal(this.reason);
  final String reason;
}

sealed class StorageDownloadResult {
  const StorageDownloadResult();
}

class StorageDownloadOk extends StorageDownloadResult {
  const StorageDownloadOk(this.bytes);
  final Uint8List bytes;
}

class StorageDownloadRetryable extends StorageDownloadResult {
  const StorageDownloadRetryable(this.reason);
  final String reason;
}

class StorageDownloadTerminal extends StorageDownloadResult {
  const StorageDownloadTerminal(this.reason);
  final String reason;
}
