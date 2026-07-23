import 'package:flutter/foundation.dart';

/// Public-facing identity inside the app. E-Mail stays private (owners
/// see it only during member-removal confirmations) — everywhere else
/// household members are referred to by [displayName].
@immutable
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromMap(Map<String, dynamic> row) {
    return UserProfile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
