/// Deterministic notification IDs derived from an (entity, uuid, slot) triple.
/// Same input → same 31-bit positive int → idempotent (re)scheduling.
///
/// The `entity` prefix keeps different entity types collision-free without
/// coordination. `slot` discriminates occurrences within a recurring entity;
/// use [slotFor] to build one from an occurrence-start + reminder offset.
///
/// Backwards-compatibility: the historical `forVaccination(uuid)` path used
/// the string `"vac:<uuid>"`. `forSlot(entity: 'vac', uuid: uuid)` with an
/// empty slot produces the same numeric ID — verified by the golden test.
class NotificationIds {
  const NotificationIds._();

  /// Build the numeric ID for a scheduled notification slot.
  static int forSlot({
    required String entity,
    required String uuid,
    String slot = '',
  }) {
    final key = slot.isEmpty ? '$entity:$uuid' : '$entity:$uuid:$slot';
    return _stableHash(key) & 0x7fffffff;
  }

  /// Compact slot key for one occurrence of a recurring reminder.
  /// Deterministic + stable across process restarts.
  static String slotFor({
    required DateTime occurrenceStart,
    int offsetMinutes = 0,
  }) {
    final utcMs = occurrenceStart.toUtc().millisecondsSinceEpoch;
    return '$utcMs:$offsetMinutes';
  }

  /// Legacy alias for the vaccination path. Preserves numeric parity with
  /// pre-refactor scheduled reminders.
  static int forVaccination(String uuid) {
    return forSlot(entity: 'vac', uuid: uuid);
  }

  static int _stableHash(String s) {
    // FNV-1a 32-bit — small, stable, dependency-free.
    var hash = 0x811c9dc5;
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
