import 'package:drift/drift.dart';

import 'foods_table.dart';

@DataClassName('FoodPhotoRow')
class FoodPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text().withLength(min: 1, max: 128)();
  TextColumn get originalFilename => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
