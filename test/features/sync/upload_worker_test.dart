import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/core/db/database.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/sync/data/media_outbox.dart';
import 'package:pet_passport/features/sync/data/upload_worker.dart';

import '../../helpers/database_helper.dart';
import '../../helpers/fake_storage_api.dart';

void main() {
  group('UploadWorker.drainOnce — happy path', () {
    test('uploads a queued file + writes storage_key back on pet_documents',
        () async {
      final db = newInMemoryDatabase();
      final outbox = MediaOutbox(db);
      final storage = FakeStorageApi();
      final worker = UploadWorker(db, storage);

      // Seed pet + pet_document owned by it — FK on pet_documents.pet_id
      // is enforced by the schema.
      final petId = await db.into(db.pets).insert(PetsCompanion.insert(
            uuid: 'p-1',
            name: 'Bello',
            species: Species.dog,
            sex: Sex.male,
            createdAt: DateTime(2026, 7, 24),
            updatedAt: DateTime(2026, 7, 24),
            householdId: const Value('h-1'),
          ));
      const docUuid = 'doc-1';
      await db.into(db.petDocuments).insert(PetDocumentsCompanion.insert(
            uuid: docUuid,
            petId: petId,
            filePath: 'ignored',
            mimeType: 'application/pdf',
            createdAt: DateTime(2026, 7, 24),
            updatedAt: DateTime(2026, 7, 24),
            householdId: const Value('h-1'),
          ));

      final tmp = File('${Directory.systemTemp.path}/pet-doc-1.pdf');
      await tmp.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      await outbox.enqueueUpload(
        entityTable: 'pet_documents',
        entityUuid: docUuid,
        localPath: tmp.path,
        storageKey: 'household/h-1/pet_documents/$docUuid.pdf',
        mimeType: 'application/pdf',
      );
      expect(await db.pendingMediaOpsDao.count(), 1);

      final result = await worker.drainOnce();
      expect(result.sent, 1);
      expect(await db.pendingMediaOpsDao.count(), 0);

      // Storage got it.
      expect(
        storage.find('media', 'household/h-1/pet_documents/$docUuid.pdf'),
        isNotNull,
      );
      // storage_key is now on the row.
      final row = await db.petDocumentsDao.getByUuid(docUuid);
      expect(row!.storageKey,
          'household/h-1/pet_documents/$docUuid.pdf');
    });

    test('retryable upload keeps the op + bumps attempts', () async {
      final db = newInMemoryDatabase();
      final outbox = MediaOutbox(db);
      final storage = FakeStorageApi()..queueUploadRetryable('flaky');
      final worker = UploadWorker(db, storage);

      final tmp = File('${Directory.systemTemp.path}/pet-doc-r.pdf');
      await tmp.writeAsBytes(Uint8List.fromList([1]));
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete();
      });

      await outbox.enqueueUpload(
        entityTable: 'pet_documents',
        entityUuid: 'doc-r',
        localPath: tmp.path,
        storageKey: 'household/h-1/pet_documents/doc-r.pdf',
      );

      final result = await worker.drainOnce();
      expect(result.retried, 1);
      expect(result.sent, 0);
      final op = (await db.pendingMediaOpsDao.head()).single;
      expect(op.attempts, 1);
      expect(op.lastError, 'flaky');
    });

    test('missing local file parks the op as terminal', () async {
      final db = newInMemoryDatabase();
      final outbox = MediaOutbox(db);
      final worker = UploadWorker(db, FakeStorageApi());

      await outbox.enqueueUpload(
        entityTable: 'pet_documents',
        entityUuid: 'doc-x',
        localPath: '/does/not/exist',
        storageKey: 'household/h-1/pet_documents/doc-x.pdf',
      );

      final r = await worker.drainOnce();
      expect(r.terminal, 1);
      final op = (await db.pendingMediaOpsDao.head()).single;
      expect(op.lastError, startsWith('terminal: source file gone'));
    });
  });

  group('UploadWorker.drainOnce — delete', () {
    test('delete op removes the storage object', () async {
      final db = newInMemoryDatabase();
      final outbox = MediaOutbox(db);
      final storage = FakeStorageApi()
        ..seed('media', 'household/h-1/pet_documents/gone.pdf',
            Uint8List.fromList([9]));
      final worker = UploadWorker(db, storage);

      await outbox.enqueueDelete(
        entityTable: 'pet_documents',
        entityUuid: 'gone',
        storageKey: 'household/h-1/pet_documents/gone.pdf',
      );

      final r = await worker.drainOnce();
      expect(r.sent, 1);
      expect(
        storage.find('media', 'household/h-1/pet_documents/gone.pdf'),
        isNull,
      );
    });
  });
}
