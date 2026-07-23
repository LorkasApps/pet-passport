import 'package:drift/drift.dart';

import '../../supabase/current_user.dart';
import '../database.dart';
import '../tables/contacts_table.dart';

part 'contacts_dao.g.dart';

@DriftAccessor(tables: [Contacts])
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  Stream<List<ContactRow>> watchForPet(int petId) {
    return (select(contacts)
          ..where((c) => c.petId.equals(petId) & c.deletedAt.isNull())
          ..orderBy([
            (c) => OrderingTerm.desc(c.isActive),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .watch();
  }

  Stream<List<ContactRow>> watchActiveForPet(int petId) {
    return (select(contacts)
          ..where((c) =>
              c.petId.equals(petId) & c.isActive.equals(true) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<ContactRow?> getByUuid(String uuid) {
    return (select(contacts)..where((c) => c.uuid.equals(uuid) & c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Same as [getByUuid] but does NOT hide soft-deleted rows. Used by
  /// sync-outbox enqueue paths that need the tombstone payload right
  /// after a soft-delete.
  Future<ContactRow?> getByUuidIncludingDeleted(String uuid) {
    return (select(contacts)..where((c) => c.uuid.equals(uuid)))
        .getSingleOrNull();
  }

  Future<ContactRow?> getById(int id) {
    return (select(contacts)..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Stream<ContactRow?> watchByUuid(String uuid) {
    return (select(contacts)..where((c) => c.uuid.equals(uuid) & c.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<int> insertContact(ContactsCompanion companion) {
    return into(contacts).insert(companion);
  }

  Future<bool> updateContact(ContactRow row) {
    return update(contacts).replace(row);
  }

  Future<int> softDeleteByUuid(String uuid, DateTime deletedAt) {
    return (update(contacts)..where((c) => c.uuid.equals(uuid)))
        .write(ContactsCompanion(
          deletedAt: Value(deletedAt),
          updatedByUserId: Value(currentUserId()),
        ));
  }

  Future<int> countForPet(int petId) async {
    final row = await (selectOnly(contacts)
          ..addColumns([contacts.id.count()])
          ..where(contacts.petId.equals(petId) & contacts.deletedAt.isNull()))
        .getSingle();
    return row.read(contacts.id.count()) ?? 0;
  }
}
