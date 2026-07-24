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

  /// Returns an absolute local path where the file lives now. Blocks
  /// on a download if we don't have it yet. Returns null on any
  /// terminal failure (missing storage key, RLS deny, 404) so
  /// callers can fall back to a placeholder.
  Future<String?> resolve({
    required String? storageKey,
    String? localHintAbsolute,
  }) async {
    if (localHintAbsolute != null) {
      final f = File(localHintAbsolute);
      if (await f.exists()) return localHintAbsolute;
    }
    if (storageKey == null) return null;

    final cached = await _cachedPath(storageKey);
    final f = File(cached);
    if (await f.exists()) return cached;

    final result = await _storage.downloadObject(
      bucket: bucket,
      key: storageKey,
    );
    switch (result) {
      case StorageDownloadOk(:final bytes):
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes, flush: true);
        return cached;
      case StorageDownloadRetryable():
      case StorageDownloadTerminal():
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
}
