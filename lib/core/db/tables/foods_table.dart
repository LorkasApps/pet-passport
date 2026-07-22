import 'package:drift/drift.dart';

import '../../../features/diet/domain/food_enums.dart';
import 'pets_table.dart';

@DataClassName('FoodRow')
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get petId =>
      integer().references(Pets, #id, onDelete: KeyAction.cascade)();
  TextColumn get brand =>
      text().withLength(min: 0, max: 200).withDefault(const Constant(''))();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get foodType => intEnum<FoodType>()
      .withDefault(const Constant(0))(); // FoodType.dry
  RealColumn get portionGrams => real().withDefault(const Constant(0))();
  IntColumn get frequencyPerDay =>
      integer().withDefault(const Constant(1))();
  TextColumn get timesOfDayJson =>
      text().withDefault(const Constant('[]'))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
