import 'package:flutter/foundation.dart';

import 'event_enums.dart';
import 'event_payload.dart';
import 'event_photo.dart';
import 'event_tag.dart';

@immutable
class Event {
  const Event({
    required this.uuid,
    required this.petUuid,
    required this.type,
    required this.occurredAt,
    this.title,
    this.note,
    required this.payload,
    this.tags = const [],
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String petUuid;
  final EventType type;
  final DateTime occurredAt;
  final String? title;
  final String? note;
  final EventPayload payload;
  final List<EventTag> tags;
  final List<EventPhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;
}
