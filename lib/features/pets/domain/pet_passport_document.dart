import 'package:flutter/foundation.dart';

@immutable
class PetPassportDocument {
  const PetPassportDocument({
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
