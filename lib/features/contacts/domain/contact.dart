import 'package:flutter/foundation.dart';

import 'contact_enums.dart';

@immutable
class Contact {
  const Contact({
    required this.uuid,
    required this.petUuid,
    required this.role,
    required this.name,
    this.organization,
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
  final ContactRole role;
  final String name;
  final String? organization;
  final String? address;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
