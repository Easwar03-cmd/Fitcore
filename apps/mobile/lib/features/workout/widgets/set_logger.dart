import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stateful form for logging a single set (reps + weight).
/// Pre-fills from the last logged set for fast re-entry.
class SetLogger extends StatefulWidget {
  const SetLogger({
    super.key,
    required this.setNumber,
    required this.onLog,
    this.lastReps,
    this.lastWeightKg,
  });

  final int setNumber;
  final void Function(int? reps, double? weightKg) onLog;
  final int? lastReps;
  final double? lastWeightKg;

  @override
  State<SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends State<SetLogger> {
  late final TextEditingController _repsCtrl;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _repsCtrl =
        TextEditingController(text: widget.lastReps?.toString() ?? '');
    _weightCtrl = TextEditingController(
        text: widget.lastWeightKg != null
            ? _formatWeight(widget.lastWeightKg!)
            : '');
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String _formatWeight(double w) =>
      w == w.truncateToDouble() ? w.toInt().toString() : w.toString();

  void _submit() {
    final reps = int.tryParse(_repsCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (reps == null && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter reps or weight to log a set.')),
      );
      return;
    }
    widget.onLog(reps, weight);
  }

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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _repsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  hintText: '10',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  hintText: '60',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
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
}
