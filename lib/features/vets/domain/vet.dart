import 'package:flutter/foundation.dart';

@immutable
class Vet {
  const Vet({
    required this.uuid,
    required this.petUuid,
    required this.name,
    this.practice,
    this.address,
    this.phone,
    this.email,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String petUuid;
  final String name;
  final String? practice;
  final String? address;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
