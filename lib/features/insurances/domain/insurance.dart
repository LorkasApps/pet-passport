import 'package:flutter/foundation.dart';

@immutable
class Insurance {
  const Insurance({
    required this.uuid,
    required this.petUuid,
    required this.provider,
    this.policyNumber,
    this.contractStart,
    this.contractEnd,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.documents = const [],
  });

  final String uuid;
  final String petUuid;
  final String provider;
  final String? policyNumber;
  final DateTime? contractStart;
  final DateTime? contractEnd;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InsuranceDocument> documents;
}

@immutable
class InsuranceDocument {
  const InsuranceDocument({
    required this.uuid,
    required this.filePath,
    required this.mimeType,
    this.originalFilename,
    this.sizeBytes,
    required this.createdAt,
  });

  final String uuid;
  final String filePath;
  final String mimeType;
  final String? originalFilename;
  final int? sizeBytes;
  final DateTime createdAt;
}
