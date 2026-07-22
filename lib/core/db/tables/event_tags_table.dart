import 'package:drift/drift.dart';

@DataClassName('EventTagRow')
class EventTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get label => text().withLength(min: 1, max: 40).unique()();
  IntColumn get color => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
