import 'package:flutter/foundation.dart';

@immutable
class Vaccination {
  const Vaccination({
    required this.uuid,
    required this.petUuid,
    required this.vaccineName,
    required this.administeredAt,
    this.nextDueAt,
    this.vetUuid,
    this.batchNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.documents = const [],
  });

  final String uuid;
  final String petUuid;
  final String vaccineName;
  final DateTime administeredAt;
  final DateTime? nextDueAt;
  final String? vetUuid;
  final String? batchNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VaccinationDocument> documents;

  bool get isOverdue {
    final due = nextDueAt;
    if (due == null) return false;
    return DateTime.now().isAfter(due);
  }
}

@immutable
class VaccinationDocument {
  const VaccinationDocument({
    required this.uuid,
    this.title,
    required this.filePath,
    this.storageKey,
    required this.mimeType,
    this.originalFilename,
    this.sizeBytes,
    required this.createdAt,
  });

  final String uuid;
  final String? title;
  final String filePath;
  final String? storageKey;
  final String mimeType;
  final String? originalFilename;
  final int? sizeBytes;
  final DateTime createdAt;

  String displayName() {
    if (title != null && title!.isNotEmpty) return title!;
    if (originalFilename != null && originalFilename!.isNotEmpty) {
      return originalFilename!;
    }
    return uuid.substring(0, 6);
  }
}
