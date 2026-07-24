import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_passport/features/export_import/data/import_service.dart';
import 'package:pet_passport/features/pets/data/pets_repository.dart';
import 'package:pet_passport/features/pets/domain/pet_enums.dart';
import 'package:pet_passport/features/vets/data/vets_repository.dart';

import '../../helpers/database_helper.dart';

/// Regression: after importing a snapshot with 1 active + 1 archived vet,
/// the overview count tile (backed by watchActiveForPetUuid) should read 1,
/// not 2. If this fails, the archive filter or the import path is dropping
/// the `is_active` flag.
void main() {
  test('vet count after import excludes archived vets', () async {
    final db = newInMemoryDatabase();

    final snapshot = jsonEncode({
      'schema_version': 3,
      'exported_at': '2026-07-23T10:00:00.000Z',
      'tags': const [],
      'pets': [
        {
          'uuid': 'pet-uuid-1',
          'name': 'Balu',
          'species': 'dog',
          'sex': 'male',
          'is_neutered': true,
          'vets': [
            {
              'uuid': 'vet-active',
              'name': 'Dr. Anna',
              'is_active': true,
              'created_at': '2026-01-01T10:00:00.000Z',
              'updated_at': '2026-01-01T10:00:00.000Z',
            },
            {
              'uuid': 'vet-archived',
              'name': 'Dr. Martin',
              'is_active': false,
              'created_at': '2025-01-01T10:00:00.000Z',
              'updated_at': '2025-06-01T10:00:00.000Z',
            },
          ],
        },
      ],
    });

    final importer = ImportService(db);
    final summary = await importer.importFromJsonString(snapshot);
    expect(summary.vetsInserted, 2);
    expect(summary.errors, isEmpty);

    final repo = VetsRepository(db.vetsDao, db.petsDao);
    final all = await repo.watchForPetUuid('pet-uuid-1').first;
    expect(all, hasLength(2));

    final active = await repo.watchActiveForPetUuid('pet-uuid-1').first;
    expect(
      active,
      hasLength(1),
      reason: 'Only the active vet should count towards the overview tile',
    );
    expect(active.single.uuid, 'vet-active');
  });

  /// Manual UI flow: create two vets, then archive one via updateVet.
  /// Verifies updateVet actually persists isActive=false.
  test('manually archiving a vet drops it from the active count', () async {
    final db = newInMemoryDatabase();
    final pets = PetsRepository(db.petsDao, db);
    final vets = VetsRepository(db.vetsDao, db.petsDao);

    final petUuid = await pets.createPet(
      name: 'Balu',
      species: Species.dog,
      sex: Sex.male,
    );
    await vets.createVet(petUuid: petUuid, name: 'Dr. Anna');
    final archivedUuid =
        await vets.createVet(petUuid: petUuid, name: 'Dr. Martin');

    expect(await vets.watchActiveForPetUuid(petUuid).first, hasLength(2));

    await vets.updateVet(
      uuid: archivedUuid,
      name: 'Dr. Martin',
      isActive: false,
    );

    final active = await vets.watchActiveForPetUuid(petUuid).first;
    expect(active, hasLength(1));
    expect(active.single.name, 'Dr. Anna');
  });
}
