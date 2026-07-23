import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/db/daos/foods_dao.dart';
import '../../../core/db/daos/pets_dao.dart';
import '../../../core/db/database.dart';
import '../../../core/media/media_service.dart';
import '../../../core/notifications/notification_ids.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/time/time_of_day_json.dart';
import '../domain/food.dart';
import '../domain/food_enums.dart';
import '../domain/food_photo.dart';

class FoodsRepository {
  FoodsRepository(
    this._foodsDao,
    this._petsDao, {
    this.notifications,
    this.media,
    Uuid? uuid,
    this.expansionHorizon = const Duration(days: 30),
    this.maxOccurrencesPerFood = 90,
  }) : _uuid = uuid ?? const Uuid();

  final FoodsDao _foodsDao;
  final PetsDao _petsDao;
  final NotificationService? notifications;
  final MediaService? media;
  final Uuid _uuid;
  final Duration expansionHorizon;
  final int maxOccurrencesPerFood;

  static const _channelId = 'feeding';
  static const _channelName = 'Feeding';
  static const _channelDesc = 'Daily reminders for feeding times.';

  Stream<List<Food>> watchForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _foodsDao.watchForPet(pet.id).map(
          (rows) => rows.map((r) => _toDomain(r, petUuid)).toList(growable: false),
        );
  }

  Stream<List<Food>> watchActiveForPetUuid(String petUuid) async* {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) {
      yield const [];
      return;
    }
    yield* _foodsDao.watchActiveForPet(pet.id).map(
          (rows) => rows.map((r) => _toDomain(r, petUuid)).toList(growable: false),
        );
  }

  Stream<Food?> watchByUuid(String uuid, String petUuid) {
    return _foodsDao
        .watchByUuid(uuid)
        .map((row) => row == null ? null : _toDomain(row, petUuid));
  }

  Future<Food?> getByUuid(String uuid, String petUuid) async {
    final row = await _foodsDao.getByUuid(uuid);
    if (row == null) return null;
    return _toDomain(row, petUuid);
  }

  Future<String> createFood({
    required String petUuid,
    required String brand,
    required String name,
    required FoodType foodType,
    double portionGrams = 0,
    int frequencyPerDay = 1,
    List<String> timesOfDay = const [],
    bool isActive = true,
    required DateTime startsAt,
    DateTime? endsAt,
    bool remindersEnabled = false,
    String? notes,
  }) async {
    final pet = await _petsDao.getByUuid(petUuid);
    if (pet == null) throw StateError('Pet not found: $petUuid');
    final now = DateTime.now();
    final foodUuid = _uuid.v4();
    await _foodsDao.insertFood(FoodsCompanion.insert(
      uuid: foodUuid,
      petId: pet.id,
      brand: Value(brand),
      name: name,
      foodType: Value(foodType),
      portionGrams: Value(portionGrams),
      frequencyPerDay: Value(frequencyPerDay),
      timesOfDayJson: Value(TimeOfDayJson.encode(timesOfDay)),
      isActive: Value(isActive),
      startsAt: startsAt,
      endsAt: Value(endsAt),
      remindersEnabled: Value(remindersEnabled),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ));
    await _rescheduleFor(foodUuid);
    return foodUuid;
  }

  Future<void> updateFood({
    required String uuid,
    required String brand,
    required String name,
    required FoodType foodType,
    double portionGrams = 0,
    int frequencyPerDay = 1,
    List<String> timesOfDay = const [],
    bool isActive = true,
    required DateTime startsAt,
    DateTime? endsAt,
    bool remindersEnabled = false,
    String? notes,
  }) async {
    final existing = await _foodsDao.getByUuid(uuid);
    if (existing == null) throw StateError('Food not found: $uuid');
    await _foodsDao.updateFood(existing.copyWith(
      brand: brand,
      name: name,
      foodType: foodType,
      portionGrams: portionGrams,
      frequencyPerDay: frequencyPerDay,
      timesOfDayJson: TimeOfDayJson.encode(timesOfDay),
      isActive: isActive,
      startsAt: startsAt,
      endsAt: Value(endsAt),
      remindersEnabled: remindersEnabled,
      notes: Value(notes),
      updatedAt: DateTime.now(),
    ));
    await notifications?.cancelAllForEntity(entity: 'feed', uuid: uuid);
    await _rescheduleFor(uuid);
  }

  Future<void> deleteByUuid(String uuid) async {
    await notifications?.cancelAllForEntity(entity: 'feed', uuid: uuid);
    // Best-effort: wipe on-disk photos before dropping the row so nothing
    // is orphaned if the media sweep never runs.
    final row = await _foodsDao.getByUuid(uuid);
    if (row != null && media != null) {
      final photoRows = await _foodsDao.watchPhotosForFood(row.id).first;
      for (final p in photoRows) {
        await media!.deleteFile(p.filePath);
      }
    }
    await _foodsDao.deleteByUuid(uuid);
  }

  // --- photos ---

  Stream<List<FoodPhoto>> watchPhotos(String foodUuid) async* {
    final row = await _foodsDao.getByUuid(foodUuid);
    if (row == null) {
      yield const [];
      return;
    }
    yield* _foodsDao.watchPhotosForFood(row.id).map(
          (rows) => rows.map(_toDomainPhoto).toList(growable: false),
        );
  }

  Future<String> attachPhoto({
    required String foodUuid,
    required File source,
    required String mimeType,
    String? originalFilename,
    int? sizeBytes,
  }) async {
    final m = media;
    if (m == null) {
      throw StateError('MediaService required to attach food photos.');
    }
    final row = await _foodsDao.getByUuid(foodUuid);
    if (row == null) throw StateError('Food with uuid=$foodUuid not found');
    final photoUuid = _uuid.v4();
    final relative = await m.saveFoodPhoto(
      foodUuid: foodUuid,
      photoUuid: photoUuid,
      source: source,
    );
    await _foodsDao.insertPhoto(FoodPhotosCompanion.insert(
      uuid: photoUuid,
      foodId: row.id,
      filePath: relative,
      mimeType: mimeType,
      originalFilename: Value(originalFilename),
      sizeBytes: Value(sizeBytes),
      createdAt: DateTime.now(),
    ));
    return photoUuid;
  }

  Future<void> removePhoto(String photoUuid) async {
    final row = await _foodsDao.getPhotoByUuid(photoUuid);
    if (row == null) return;
    await media?.deleteFile(row.filePath);
    await _foodsDao.deletePhotoByUuid(photoUuid);
  }

  FoodPhoto _toDomainPhoto(FoodPhotoRow row) {
    return FoodPhoto(
      uuid: row.uuid,
      filePath: row.filePath,
      mimeType: row.mimeType,
      originalFilename: row.originalFilename,
      sizeBytes: row.sizeBytes,
      createdAt: row.createdAt,
    );
  }

  Future<void> rescheduleAllUpcomingReminders() async {
    final notif = notifications;
    if (notif == null) return;
    final rows = await _foodsDao.getAllActiveWithReminders();
    for (final row in rows) {
      await _rescheduleForRow(row);
    }
  }

  Future<void> _rescheduleFor(String uuid) async {
    final row = await _foodsDao.getByUuid(uuid);
    if (row == null) return;
    await _rescheduleForRow(row);
  }

  Future<void> _rescheduleForRow(FoodRow row) async {
    final notif = notifications;
    if (notif == null || !row.isActive || !row.remindersEnabled) return;
    final times = TimeOfDayJson.decode(row.timesOfDayJson);
    if (times.isEmpty) return;
    final now = DateTime.now();
    final to = now.add(expansionHorizon);
    final endsAt = row.endsAt;
    final horizonEnd = endsAt != null && endsAt.isBefore(to) ? endsAt : to;
    final pet = await _petsDao.getById(row.petId);
    final petName = pet?.name ?? '';

    final startDay = DateTime(row.startsAt.year, row.startsAt.month, row.startsAt.day);
    final fromDay = DateTime(now.year, now.month, now.day);
    final firstDay = fromDay.isAfter(startDay) ? fromDay : startDay;

    var emitted = 0;
    for (var day = firstDay;
        !day.isAfter(horizonEnd);
        day = day.add(const Duration(days: 1))) {
      for (final t in times) {
        final parts = t.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final occ = DateTime(day.year, day.month, day.day, hour, minute);
        if (occ.isBefore(row.startsAt) || occ.isAfter(horizonEnd)) continue;
        if (!occ.isAfter(now)) continue;
        final slot =
            NotificationIds.slotFor(occurrenceStart: occ, offsetMinutes: 0);
        await notif.scheduleReminder(
          entity: 'feed',
          uuid: row.uuid,
          slot: slot,
          channelId: _channelId,
          channelName: _channelName,
          channelDescription: _channelDesc,
          title: petName.isEmpty ? row.name : '$petName: ${row.name}',
          body: _buildBody(row),
          whenLocal: occ,
        );
        emitted++;
        if (emitted >= maxOccurrencesPerFood) return;
      }
    }
  }

  String _buildBody(FoodRow row) {
    final portion = row.portionGrams;
    if (portion <= 0) return row.brand.isEmpty ? row.name : '${row.brand} · ${row.name}';
    final amount =
        portion % 1 == 0 ? portion.toStringAsFixed(0) : portion.toString();
    final head = row.brand.isEmpty ? row.name : '${row.brand} · ${row.name}';
    return '$head — $amount g';
  }

  Food _toDomain(FoodRow row, String petUuid) {
    return Food(
      uuid: row.uuid,
      petUuid: petUuid,
      brand: row.brand,
      name: row.name,
      foodType: row.foodType,
      portionGrams: row.portionGrams,
      frequencyPerDay: row.frequencyPerDay,
      timesOfDay: TimeOfDayJson.decode(row.timesOfDayJson),
      isActive: row.isActive,
      startsAt: row.startsAt,
      endsAt: row.endsAt,
      remindersEnabled: row.remindersEnabled,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
