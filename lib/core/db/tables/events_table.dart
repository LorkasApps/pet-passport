import 'package:drift/drift.dart';

import '../../../features/protocol/domain/event_enums.dart';
import 'pets_table.dart';

@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  IntColumn get eventType => intEnum<EventType>()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get title => text().withLength(min: 1, max: 200).nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get householdId => text().nullable()();
  TextColumn get updatedByUserId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
