import 'package:flutter/foundation.dart';

enum HouseholdRole { owner, member }

HouseholdRole householdRoleFromRaw(String? raw) => switch (raw) {
      'owner' => HouseholdRole.owner,
      _ => HouseholdRole.member,
    };

/// One household the current user is a member of. `role` is *my* role
/// inside this household (owner or member); `memberCount` includes the
/// caller.
@immutable
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.role,
    required this.memberCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final HouseholdRole role;
  final int memberCount;
  final DateTime createdAt;

  bool get isOwner => role == HouseholdRole.owner;
}
