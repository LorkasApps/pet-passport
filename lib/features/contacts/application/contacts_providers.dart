import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/contacts_repository.dart';
import '../domain/contact.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final outbox = ref.watch(syncOutboxProvider);
  return ContactsRepository(db.contactsDao, db.petsDao, outbox: outbox);
});

final contactsForPetProvider =
    StreamProvider.family<List<Contact>, String>((ref, petUuid) {
  return ref.watch(contactsRepositoryProvider).watchForPetUuid(petUuid);
});

final activeContactsForPetProvider =
    StreamProvider.family<List<Contact>, String>((ref, petUuid) {
  return ref
      .watch(contactsRepositoryProvider)
      .watchActiveForPetUuid(petUuid);
});

final contactCountForPetProvider =
    StreamProvider.family<int, String>((ref, petUuid) {
  return ref
      .watch(contactsRepositoryProvider)
      .watchActiveForPetUuid(petUuid)
      .map((list) => list.length);
});

final contactByUuidProvider = StreamProvider.family<Contact?,
    ({String contactUuid, String petUuid})>((ref, args) {
  return ref
      .watch(contactsRepositoryProvider)
      .watchByUuid(args.contactUuid, args.petUuid);
});
