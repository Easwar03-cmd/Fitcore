import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/body_stat.dart';
import '../providers/body_log_provider.dart';

class BodyLogScreen extends ConsumerStatefulWidget {
  const BodyLogScreen({super.key});

  @override
  ConsumerState<BodyLogScreen> createState() => _BodyLogScreenState();
}

class _BodyLogScreenState extends ConsumerState<BodyLogScreen> {
  final _weightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  bool _saving = false;
  // Pre-fill flag — only fill from cache once.
  bool _preFilledWeight = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    super.dispose();
  }

  String get _todayLabel {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Future<void> _save() async {
    final wt = double.tryParse(_weightCtrl.text.trim());
    if (wt == null || wt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight in kg.')),
      );
      return;
    }
    final bf = double.tryParse(_bodyFatCtrl.text.trim());
    setState(() => _saving = true);
    try {
      await ref
          .read(bodyLogProvider.notifier)
          .logWeight(weightKg: wt, bodyFatPct: bf);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weight saved: ${wt.toStringAsFixed(1)} kg'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      _weightCtrl.clear();
      _bodyFatCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(bodyLogProvider);

    // Pre-fill weight field from last entry once data arrives.
    ref.listen<AsyncValue<List<BodyStat>>>(bodyLogProvider, (_, next) {
      if (_preFilledWeight) return;
      final stats = next.valueOrNull;
      if (stats != null && stats.isNotEmpty && stats.first.weightKg != null) {
        if (_weightCtrl.text.isEmpty) {
          _weightCtrl.text =
              _formatWeight(stats.first.weightKg!);
        }
        _preFilledWeight = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Log Body Weight')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(bodyLogProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Input card ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date row
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          _todayLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Weight field
                    TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        hintText: '75.0',
                        border: OutlineInputBorder(),
                        suffixText: 'kg',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Body fat field (optional)
                    TextField(
                      controller: _bodyFatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Body Fat % (optional)',
                        hintText: '18.5',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14)),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text('Save Weight'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── History list ──────────────────────────────────────────────
            Text('Recent Entries',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.toString().replaceAll('Exception: ', ''),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(bodyLogProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (stats) => stats.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No entries yet.')),
                    )
                  : Column(
                      children: stats
                          .map((s) => _StatRow(stat: s))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatWeight(double w) =>
      w == w.truncateToDouble()
          ? w.toInt().toString()
          : w.toStringAsFixed(1);
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stat});

  final BodyStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _formatDate(stat.measuredAt);
    final weight = stat.weightKg != null
        ? '${stat.weightKg!.toStringAsFixed(1)} kg'
        : '—';
    final bf = stat.bodyFatPct != null
        ? '  ·  ${stat.bodyFatPct!.toStringAsFixed(1)}%'
        : '';

    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(date,
                    style: theme.textTheme.bodyMedium),
              ),
              Text(
                '$weight$bf',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
