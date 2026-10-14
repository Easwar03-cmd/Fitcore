import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'notepad_field.dart';

/// Day grid + one notepad sheet per challenge day.
///
/// Tapping a day opens that day's sheet; days that have not been reached yet
/// are locked. Notes autosave per day through [onSave].
class ChallengeDaySheets extends StatefulWidget {
  const ChallengeDaySheets({
    super.key,
    required this.totalDays,
    required this.startDate,
    required this.todayNo,
    required this.done,
    required this.dayNotes,
    required this.onSave,
    this.onShare,
  });

  final int totalDays;
  final DateTime startDate;

  /// 1-based number of today within the challenge; null before day 1.
  final int? todayNo;
  final Set<int> done;
  final Map<int, String> dayNotes;
  final Future<void> Function(int day, String text) onSave;

  /// Shares the given day's sheet to the community chat (null = hidden).
  final Future<void> Function(int day)? onShare;

  @override
  State<ChallengeDaySheets> createState() => _ChallengeDaySheetsState();
}

class _ChallengeDaySheetsState extends State<ChallengeDaySheets> {
  late int _day = _defaultDay();

  /// Latest text per day, so switching days and coming back shows what was
  /// just typed even before the server copy is refreshed.
  final Map<int, String> _edits = {};

  int _defaultDay() {
    final t = widget.todayNo;
    if (t == null) return 1;
    return t.clamp(1, widget.totalDays);
  }

  int get _lastOpenDay {
    final t = widget.todayNo;
    return t == null ? 0 : t.clamp(0, widget.totalDays);
  }

  bool _hasNote(int d) =>
      (_edits[d] ?? widget.dayNotes[d] ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = widget.startDate.add(Duration(days: _day - 1));
    final locked = _day > _lastOpenDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= widget.totalDays; d++)
              _DayCell(
                day: d,
                done: widget.done.contains(d),
                today: d == widget.todayNo,
                missed: !widget.done.contains(d) &&
                    widget.todayNo != null &&
                    d < widget.todayNo!,
                selected: d == _day,
                hasNote: _hasNote(d),
                locked: d > _lastOpenDay,
                onTap: () => setState(() => _day = d),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Day $_day notes', style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(DateFormat('d MMM y').format(date),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
            if (_day == widget.todayNo) ...[
              const SizedBox(width: 8),
              const Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Today'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (locked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Day $_day opens on ${DateFormat('d MMM').format(date)}.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          // Keyed by day so each sheet gets its own controller and autosave.
          NotepadField(
            key: ValueKey('day-$_day'),
            initialText: _edits[_day] ?? widget.dayNotes[_day] ?? '',
            onChanged: (t) {
              final had = _hasNote(_day);
              _edits[_day] = t;
              if (had != _hasNote(_day)) setState(() {});
            },
            onSave: (text) => widget.onSave(_day, text),
          ),
          if (widget.onShare != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => widget.onShare!(_day),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text('Share day $_day in community'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.done,
    required this.today,
    required this.missed,
    required this.selected,
    required this.hasNote,
    required this.locked,
    required this.onTap,
  });

  final int day;
  final bool done;
  final bool today;
  final bool missed;
  final bool selected;
  final bool hasNote;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $day${done ? ', completed' : ''}${hasNote ? ', has notes' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? cs.primary
                : missed
                    ? cs.errorContainer.withValues(alpha: 0.5)
                    : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: cs.primary, width: 2.5)
                : today
                    ? Border.all(color: cs.primary, width: 1.5)
                    : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              done
                  ? Icon(Icons.check_rounded, size: 18, color: cs.onPrimary)
                  : Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        color: locked
                            ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                            : cs.onSurface,
                      ),
                    ),
              if (hasNote)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: done ? cs.onPrimary : cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
