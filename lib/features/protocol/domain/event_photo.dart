import 'package:flutter/foundation.dart';

@immutable
class EventPhoto {
  const EventPhoto({
    required this.uuid,
    required this.filePath,
    required this.mimeType,
    this.sizeBytes,
    required this.createdAt,
  });

  final String uuid;
  final String filePath;
  final String mimeType;
  final int? sizeBytes;
  final DateTime createdAt;
}
