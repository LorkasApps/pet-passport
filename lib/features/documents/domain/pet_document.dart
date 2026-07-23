import 'package:flutter/foundation.dart';

@immutable
class PetDocument {
  const PetDocument({
    required this.uuid,
    required this.petUuid,
    this.title,
    required this.filePath,
    required this.mimeType,
    this.originalFilename,
    this.sizeBytes,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String petUuid;
  final String? title;
  final String filePath;
  final String mimeType;
  final String? originalFilename;
  final int? sizeBytes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Best-effort display label: user-provided title takes priority, then
  /// the original filename, then the uuid short-hash as last resort.
  String displayName() {
    if (title != null && title!.isNotEmpty) return title!;
    if (originalFilename != null && originalFilename!.isNotEmpty) {
      return originalFilename!;
    }
    return uuid.substring(0, 6);
  }
}
