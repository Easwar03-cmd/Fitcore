import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How the set-logger collects input for an exercise.
enum SetInputMode {
  /// Classic gym lift: reps + weight (kg).
  repsAndWeight,

  /// Bodyweight exercise: reps only, no weight field.
  repsOnly,

  /// Timed exercise (plank, wall sit…): duration in seconds only.
  durationOnly,
}

/// Stateful form for logging a single set.
/// Pre-fills from the last logged set for fast re-entry.
class SetLogger extends StatefulWidget {
  const SetLogger({
    super.key,
    required this.setNumber,
    required this.onLog,
    this.inputMode = SetInputMode.repsAndWeight,
    this.lastReps,
    this.lastWeightKg,
    this.lastDurationSec,
  });

  final int setNumber;

  /// Callback: (reps, weightKg, durationSec) — nulls for unused fields.
  final void Function(int? reps, double? weightKg, int? durationSec) onLog;
  final SetInputMode inputMode;
  final int? lastReps;
  final double? lastWeightKg;
  final int? lastDurationSec;

  @override
  State<SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends State<SetLogger> {
  late final TextEditingController _repsCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _durationCtrl;

  @override
  void initState() {
    super.initState();
    _repsCtrl =
        TextEditingController(text: widget.lastReps?.toString() ?? '');
    _weightCtrl = TextEditingController(
        text: widget.lastWeightKg != null
            ? _formatWeight(widget.lastWeightKg!)
            : '');
    _durationCtrl =
        TextEditingController(text: widget.lastDurationSec?.toString() ?? '');
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  String _formatWeight(double w) =>
      w == w.truncateToDouble() ? w.toInt().toString() : w.toString();

  void _submit() {
    switch (widget.inputMode) {
      case SetInputMode.repsAndWeight:
        final reps = int.tryParse(_repsCtrl.text.trim());
        final weight = double.tryParse(_weightCtrl.text.trim());
        if (reps == null && weight == null) {
          _showSnack('Enter reps or weight to log a set.');
          return;
        }
        widget.onLog(reps, weight, null);

      case SetInputMode.repsOnly:
        final reps = int.tryParse(_repsCtrl.text.trim());
        if (reps == null || reps <= 0) {
          _showSnack('Enter the number of reps to log a set.');
          return;
        }
        widget.onLog(reps, null, null);

      case SetInputMode.durationOnly:
        final secs = int.tryParse(_durationCtrl.text.trim());
        if (secs == null || secs <= 0) {
          _showSnack('Enter the duration in seconds to log a set.');
          return;
        }
        widget.onLog(null, null, secs);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set ${widget.setNumber}',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInputRow(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('Add Set'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow() {
    return switch (widget.inputMode) {
      SetInputMode.repsAndWeight => Row(
          children: [
            Expanded(child: _repsField()),
            const SizedBox(width: 12),
            Expanded(child: _weightField()),
          ],
        ),
      SetInputMode.repsOnly => _repsField(),
      SetInputMode.durationOnly => _durationField(),
    };
  }

  Widget _repsField() => TextField(
        controller: _repsCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Reps',
          hintText: '10',
          border: OutlineInputBorder(),
        ),
      );

  Widget _weightField() => TextField(
        controller: _weightCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Weight (kg)',
          hintText: '60',
          border: OutlineInputBorder(),
        ),
      );

  Widget _durationField() => TextField(
        controller: _durationCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Duration (sec)',
          hintText: '30',
          border: OutlineInputBorder(),
        ),
      );
}
