import 'dart:convert';

/// Codec for a sorted, deduped list of `HH:mm` strings persisted as JSON.
/// Used by `medications.times_of_day_json`. Defensive on malformed input
/// (returns empty list rather than throwing at read).
class TimeOfDayJson {
  const TimeOfDayJson._();

  static final RegExp _pattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  static String encode(Iterable<String> times) {
    final normalized = times
        .map((t) => t.trim())
        .where(_pattern.hasMatch)
        .toSet()
        .toList()
      ..sort();
    return jsonEncode(normalized);
  }

  static List<String> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .where(_pattern.hasMatch)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static bool isValid(String value) => _pattern.hasMatch(value);
}
