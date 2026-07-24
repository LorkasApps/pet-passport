import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pet_passport/features/sync/data/media_fetcher.dart';
import 'package:pet_passport/features/sync/data/storage_api.dart';

import '../../helpers/fake_storage_api.dart';

Future<Directory> _tempCacheDir() async {
  final base = await Directory.systemTemp.createTemp('media-fetcher-');
  return base;
}

void main() {
  group('MediaFetcher.resolve', () {
    test('returns the local hint when the file already exists on disk',
        () async {
      final storage = FakeStorageApi();
      final fetcher = MediaFetcher(storage, cacheDirLoader: _tempCacheDir);

      final tmp = File('${Directory.systemTemp.path}/mf-local.txt');
      await tmp.writeAsString('hi');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      final resolved = await fetcher.resolve(
        storageKey: 'household/h/pets/p/profile.jpg',
        localHintAbsolute: tmp.path,
      );
      expect(resolved, tmp.path);
      // Storage was never touched.
      expect(storage.uploadCalls, isEmpty);
    });

    test('downloads on first miss and caches for the next call',
        () async {
      final storage = FakeStorageApi()
        ..seed('media', 'household/h/pet_documents/d.pdf',
            Uint8List.fromList([1, 2, 3]));
      final cacheDir = await _tempCacheDir();
      final fetcher =
          MediaFetcher(storage, cacheDirLoader: () async => cacheDir);

      // Local hint doesn't exist → miss → download.
      final first = await fetcher.resolve(
        storageKey: 'household/h/pet_documents/d.pdf',
        localHintAbsolute: '/does/not/exist',
      );
      expect(first, isNotNull);
      expect(await File(first!).readAsBytes(),
          Uint8List.fromList([1, 2, 3]));

      // Second call: cached, no new storage read.
      // Force a terminal on any further download so we know the
      // fetcher didn't touch the API.
      storage.queueDownloadResult(
          const StorageDownloadTerminal('should not run'));
      final second = await fetcher.resolve(
        storageKey: 'household/h/pet_documents/d.pdf',
        localHintAbsolute: '/does/not/exist',
      );
      expect(second, first);
    });

    test('returns null on 404 (terminal) so viewers can fall back',
        () async {
      final storage = FakeStorageApi();
      final fetcher = MediaFetcher(storage, cacheDirLoader: _tempCacheDir);

      final resolved = await fetcher.resolve(
        storageKey: 'household/h/pets/p/profile.jpg',
      );
      expect(resolved, isNull);
    });
  });

  group('MediaFetcher.sweep', () {
    test('no-op when total cache is under cap', () async {
      final storage = FakeStorageApi()
        ..seed('media', 'household/h/pet_documents/small.pdf',
            Uint8List.fromList(List.filled(100, 1)));
      final cacheDir = await _tempCacheDir();
      final fetcher = MediaFetcher(storage,
          cacheDirLoader: () async => cacheDir);
      await fetcher.resolve(
        storageKey: 'household/h/pet_documents/small.pdf',
      );

      final result = await fetcher.sweep(maxBytes: 100 * 1024 * 1024);
      expect(result.deletedFiles, 0);
    });

    test('evicts oldest first once cap is exceeded', () async {
      final cacheDir = await _tempCacheDir();
      final storage = FakeStorageApi();
      final fetcher = MediaFetcher(storage,
          cacheDirLoader: () async => cacheDir);

      // Seed + fetch three files. Their mtimes will be strictly
      // increasing as long as we sleep briefly between writes.
      Future<void> put(String key, int bytes) async {
        storage.seed('media', key, Uint8List(bytes));
        await fetcher.resolve(storageKey: key);
        // Grow the mtime spread so the sort is unambiguous even on
        // very fast filesystems that share a second-resolution stat.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await put('household/h/pet_documents/oldest.pdf', 1000);
      await put('household/h/pet_documents/middle.pdf', 1000);
      await put('household/h/pet_documents/newest.pdf', 1000);

      // Cap at 2 KB → one file has to go, and it must be the oldest.
      final result = await fetcher.sweep(maxBytes: 2000);
      expect(result.deletedFiles, greaterThanOrEqualTo(1));
      expect(result.totalBytesAfter, lessThanOrEqualTo(2000));

      // The oldest write is the eviction target — check it's gone
      // while the newest survives.
      final oldest = File(p.join(
          cacheDir.path, 'media-cache/household/h/pet_documents/oldest.pdf'));
      final newest = File(p.join(
          cacheDir.path, 'media-cache/household/h/pet_documents/newest.pdf'));
      expect(await oldest.exists(), isFalse);
      expect(await newest.exists(), isTrue);
    });
  });
}
