import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../features/appointments/domain/appointment_enums.dart';
import '../time/recurrence.dart';

/// Editor for a [RecurrenceSpec]. Emits changes via [onChanged]. Shows
/// interval + weekday chips only when relevant.
class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RecurrenceSpec value;
  final ValueChanged<RecurrenceSpec> onChanged;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  late RecurrenceSpec _spec = widget.value;

  void _update(RecurrenceSpec next) {
    setState(() => _spec = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<RecurrenceFreq>(
          initialValue: _spec.freq,
          decoration: InputDecoration(labelText: l.recurrenceFrequencyLabel),
          items: [
            DropdownMenuItem(
              value: RecurrenceFreq.none,
              child: Text(l.recurrenceNone),
            ),
            DropdownMenuItem(
              value: RecurrenceFreq.daily,
              child: Text(l.recurrenceDaily),
            ),
            DropdownMenuItem(
              value: RecurrenceFreq.weekly,
              child: Text(l.recurrenceWeekly),
            ),
            DropdownMenuItem(
              value: RecurrenceFreq.monthly,
              child: Text(l.recurrenceMonthly),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            _update(RecurrenceSpec(
              freq: v,
              interval: _spec.interval,
              weekdaysBitmask: _spec.weekdaysBitmask,
              until: _spec.until,
            ));
          },
        ),
        if (_spec.freq != RecurrenceFreq.none) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _spec.interval.toString(),
                  decoration:
                      InputDecoration(labelText: l.recurrenceIntervalLabel),
                  keyboardType: TextInputType.number,
                  onChanged: (raw) {
                    final n = int.tryParse(raw) ?? 1;
                    _update(RecurrenceSpec(
                      freq: _spec.freq,
                      interval: n < 1 ? 1 : n,
                      weekdaysBitmask: _spec.weekdaysBitmask,
                      until: _spec.until,
                    ));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_intervalHint(l, _spec.freq)),
              ),
            ],
          ),
          if (_spec.freq == RecurrenceFreq.weekly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final weekday = i + 1; // Mon=1..Sun=7
                final bit = RecurrenceSpec.weekdayBit(weekday);
                final on = (_spec.weekdaysBitmask & bit) != 0;
                return FilterChip(
                  label: Text(_weekdayShort(l, weekday)),
                  selected: on,
                  onSelected: (sel) {
                    final next = sel
                        ? _spec.weekdaysBitmask | bit
                        : _spec.weekdaysBitmask & ~bit;
                    _update(RecurrenceSpec(
                      freq: _spec.freq,
                      interval: _spec.interval,
                      weekdaysBitmask: next,
                      until: _spec.until,
                    ));
                  },
                );
              }),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _spec.until == null
                      ? l.recurrenceUntilNone
                      : l.recurrenceUntilLabel(
                          DateFormat.yMd(locale).format(_spec.until!)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _spec.until ??
                        DateTime(now.year + 1, now.month, now.day),
                    firstDate: now,
                    lastDate: DateTime(now.year + 20),
                  );
                  if (picked != null) {
                    _update(RecurrenceSpec(
                      freq: _spec.freq,
                      interval: _spec.interval,
                      weekdaysBitmask: _spec.weekdaysBitmask,
                      until: picked,
                    ));
                  }
                },
                child: Text(l.recurrenceUntilPick),
              ),
              if (_spec.until != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l.actionClear,
                  onPressed: () => _update(RecurrenceSpec(
                    freq: _spec.freq,
                    interval: _spec.interval,
                    weekdaysBitmask: _spec.weekdaysBitmask,
                  )),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _intervalHint(AppL10n l, RecurrenceFreq freq) {
    switch (freq) {
      case RecurrenceFreq.daily:
        return l.recurrenceHintDaily(_spec.interval);
      case RecurrenceFreq.weekly:
        return l.recurrenceHintWeekly(_spec.interval);
      case RecurrenceFreq.monthly:
        return l.recurrenceHintMonthly(_spec.interval);
      case RecurrenceFreq.none:
        return '';
    }
  }

  String _weekdayShort(AppL10n l, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return l.weekdayShortMon;
      case DateTime.tuesday:
        return l.weekdayShortTue;
      case DateTime.wednesday:
        return l.weekdayShortWed;
      case DateTime.thursday:
        return l.weekdayShortThu;
      case DateTime.friday:
        return l.weekdayShortFri;
      case DateTime.saturday:
        return l.weekdayShortSat;
      case DateTime.sunday:
        return l.weekdayShortSun;
      default:
        return '';
    }
  }
}
