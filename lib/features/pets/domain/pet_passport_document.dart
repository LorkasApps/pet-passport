import 'package:flutter/foundation.dart';

@immutable
class PetPassportDocument {
  const PetPassportDocument({
    required this.uuid,
    this.title,
    required this.filePath,
    required this.mimeType,
    this.originalFilename,
    this.sizeBytes,
    required this.createdAt,
  });

  final String uuid;
  final String? title;
  final String filePath;
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
