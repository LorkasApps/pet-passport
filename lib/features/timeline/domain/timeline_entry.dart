import 'package:flutter/material.dart';

/// Category of timeline entry — governs the icon, label and filter chip.
/// Order is display-only, safe to reorder.
enum TimelineKind { event, vaccination, medicationIntake, appointment }

@immutable
class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.entityUuid,
    required this.petUuid,
    required this.petName,
    required this.at,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.route,
  });

  final TimelineKind kind;
  final String entityUuid;
  final String petUuid;
  final String petName;
  final DateTime at;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String route;
}
