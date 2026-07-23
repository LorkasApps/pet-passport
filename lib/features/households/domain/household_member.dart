import 'package:flutter/foundation.dart';

import 'household.dart';

/// A row from `household_members` joined with `user_profiles` so we
/// have the human-readable [displayName] alongside the [role].
@immutable
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final HouseholdRole role;
  final DateTime joinedAt;

  bool get isOwner => role == HouseholdRole.owner;
}
