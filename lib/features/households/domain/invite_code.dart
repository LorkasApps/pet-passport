import 'package:flutter/foundation.dart';

/// One row from `public.invite_codes` — a household join token with a
/// TTL. Single-use: `usedAt` flips non-null on redemption and the code
/// is done.
@immutable
class InviteCode {
  const InviteCode({
    required this.id,
    required this.householdId,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    this.usedAt,
  });

  final String id;
  final String householdId;
  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? usedAt;

  bool get isUsed => usedAt != null;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isUsed && !isExpired;

  /// Deep link a scanner or link-tap uses to bounce back into the app.
  /// Same scheme the auth callback uses, different path.
  String get deepLink => 'petpassport://invite/$token';

  factory InviteCode.fromRow(Map<String, dynamic> row) {
    return InviteCode(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      token: row['token'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      usedAt: row['used_at'] == null
          ? null
          : DateTime.parse(row['used_at'] as String),
    );
  }
}
