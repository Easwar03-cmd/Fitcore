import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'body_figure.dart';
import 'pastel_chip.dart';

/// "Muscles workload" picker (reference screen A): a scrolling row of body
/// tiles, one per muscle, each showing the highlighted region and this week's
/// set count. The selected tile gets a teal outline; an optional CTA starts a
/// session for that muscle.
class MuscleWorkloadCard extends StatefulWidget {
  const MuscleWorkloadCard({
    super.key,
    required this.volume,
    this.onTrain,
    this.initial = MuscleKey.shoulders,
    this.minEffectiveSets = 10,
    this.maxRecoverableSets = 20,
  });

  /// Sets this week per [MuscleKey.id].
  final Map<String, int> volume;

  /// Called with the selected muscle when the user taps "Train …".
  /// When null the card is read-only (Progress screen).
  final ValueChanged<MuscleKey>? onTrain;
  final MuscleKey initial;
  final int minEffectiveSets;
  final int maxRecoverableSets;

  @override
  State<MuscleWorkloadCard> createState() => _MuscleWorkloadCardState();
}

class _MuscleWorkloadCardState extends State<MuscleWorkloadCard> {
  late MuscleKey _selected = widget.initial;

  int _sets(MuscleKey k) => widget.volume[k.id] ?? 0;

  (String, PastelTint) _status(int sets) {
    if (sets == 0) return ('No sets yet', PastelTint.butter);
    if (sets < widget.minEffectiveSets) return ('Needs more work', PastelTint.butter);
    if (sets > widget.maxRecoverableSets) return ('High volume', PastelTint.salmon);
    return ('Optimal', PastelTint.lime);
  }

  @override
  Widget build(BuildContext context) {
    final sets = _sets(_selected);
    final (statusLabel, statusTint) = _status(sets);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Muscles workload', style: AppTextStyles.heading),
                ),
                const SizedBox(height: 2),
                Text('Select the muscle you want to make strong',
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 212,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: MuscleKey.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final k = MuscleKey.values[i];
                return _Tile(
                  muscle: k,
                  sets: _sets(k),
                  selected: k == _selected,
                  onTap: () => setState(() => _selected = k),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Row(
                key: ValueKey(_selected),
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selected.label, style: AppTextStyles.metricM),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('$sets sets this week',
                                style: AppTextStyles.caption),
                            PastelChip(
                              label: statusLabel,
                              background: statusTint.color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.onTrain != null)
                    FilledButton.icon(
                      onPressed: () => widget.onTrain!(_selected),
                      icon: const Icon(PhosphorIconsBold.arrowRight, size: 16),
                      label: const Text('Train'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.muscle,
    required this.sets,
    required this.selected,
    required this.onTap,
  });

  final MuscleKey muscle;
  final int sets;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${muscle.label}, $sets sets this week',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 108,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: selected ? AppColors.tealBright : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: BodyFigure(
                    view: muscle.view,
                    highlight: muscle,
                    height: 128,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(muscle.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
              Text('$sets sets',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
