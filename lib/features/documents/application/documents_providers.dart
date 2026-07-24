import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pets/application/pets_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/documents_repository.dart';
import '../domain/pet_document.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final media = ref.watch(mediaServiceProvider);
  final outbox = ref.watch(syncOutboxProvider);
  final mediaOutbox = ref.watch(mediaOutboxProvider);
  return DocumentsRepository(
    db.petDocumentsDao,
    db.petsDao,
    media,
    outbox: outbox,
    mediaOutbox: mediaOutbox,
  );
});

final petDocumentsProvider =
    StreamProvider.family<List<PetDocument>, String>((ref, petUuid) {
  return ref
      .watch(documentsRepositoryProvider)
      .watchForPetUuid(petUuid);
});

final petDocumentsCountProvider =
    StreamProvider.family<int, String>((ref, petUuid) {
  return ref
      .watch(documentsRepositoryProvider)
      .watchForPetUuid(petUuid)
      .map((list) => list.length);
});
