import 'package:flutter/foundation.dart';

@immutable
class EventTag {
  const EventTag({
    required this.uuid,
    required this.label,
    this.color,
    required this.createdAt,
  });

  final String uuid;
  final String label;
  final int? color;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTag && other.uuid == uuid);

  @override
  int get hashCode => uuid.hashCode;
}
