import 'package:flutter/foundation.dart';

@immutable
class EventPhoto {
  const EventPhoto({
    required this.uuid,
    this.title,
    required this.filePath,
    required this.mimeType,
    this.sizeBytes,
    required this.createdAt,
  });

  final String uuid;
  final String? title;
  final String filePath;
  final String mimeType;
  final int? sizeBytes;
  final DateTime createdAt;

  /// User-provided title if any; otherwise a short uuid slice so the UI
  /// always has *something* to render on a chip / list tile.
  String displayName() => (title != null && title!.isNotEmpty)
      ? title!
      : uuid.substring(0, 6);
}
