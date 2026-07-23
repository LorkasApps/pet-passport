import 'package:drift/drift.dart';

import 'events_table.dart';

@DataClassName('EventPhotoRow')
class EventPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get eventId =>
      integer().references(Events, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
