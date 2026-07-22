import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

/// Multi-select chip row for reminder offsets (minutes before the occurrence).
/// Presets: none / 15 min / 60 min / 1 day. Emits the selected set.
class ReminderOffsetChips extends StatelessWidget {
  const ReminderOffsetChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = const [0, 15, 60, 60 * 24],
  });

  final List<int> value;
  final ValueChanged<List<int>> onChanged;
  final List<int> presets;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final selected = value.toSet();
    return Wrap(
      spacing: 6,
      children: [
        for (final p in presets)
          FilterChip(
            label: Text(_label(l, p)),
            selected: selected.contains(p),
            onSelected: (sel) {
              final next = {...selected};
              if (sel) {
                next.add(p);
              } else {
                next.remove(p);
              }
              final list = next.toList()..sort();
              onChanged(list);
            },
          ),
      ],
    );
  }

  String _label(AppL10n l, int minutes) {
    if (minutes == 0) return l.reminderOffsetAtTime;
    if (minutes < 60) return l.reminderOffsetMinutes(minutes);
    if (minutes < 60 * 24) return l.reminderOffsetHours(minutes ~/ 60);
    return l.reminderOffsetDays(minutes ~/ (60 * 24));
  }
}
