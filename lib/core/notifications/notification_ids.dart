/// Deterministic notification IDs derived from an entity slot.
/// Same input → same ID → idempotent (re)scheduling.
class NotificationIds {
  const NotificationIds._();

  static int forVaccination(String uuid) {
    return _stableHash('vac:$uuid') & 0x7fffffff;
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
