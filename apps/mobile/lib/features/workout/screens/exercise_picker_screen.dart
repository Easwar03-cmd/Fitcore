import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/exercise.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key, this.initialGroup});

  /// When set, only this muscle group is listed (opened from the muscle picker).
  final MuscleGroup? initialGroup;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  String _query = '';
  late MuscleGroup? _group = widget.initialGroup;

  Map<MuscleGroup, List<Exercise>> get _grouped {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? kExerciseLibrary
        : kExerciseLibrary
            .where((e) => e.name.toLowerCase().contains(q))
            .toList();

    final map = <MuscleGroup, List<Exercise>>{};
    for (final group in MuscleGroup.values) {
      if (_group != null && group != _group) continue;
      final list = filtered.where((e) => e.muscleGroup == group).toList();
      if (list.isNotEmpty) map[group] = list;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      appBar: const PageAppBar(title: 'Pick Exercise'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_group != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('Showing ${_group!.label}'),
                  avatar: Icon(_group!.icon, size: 16),
                  onDeleted: () => setState(() => _group = null),
                  deleteButtonTooltipMessage: 'Show all muscle groups',
                  backgroundColor: _group!.color,
                ),
              ),
            ),
          Expanded(
            child: grouped.isEmpty
                ? const EmptyState(
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    title: 'No exercises found',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final group = grouped.keys.elementAt(index);
                      final exercises = grouped[group]!;
                      return _MuscleGroupSection(
                        group: group,
                        exercises: exercises,
                        onSelect: (e) => context.pop<Exercise>(e),
                      ).animate().fadeIn(
                            delay: Duration(milliseconds: index * 40),
                            duration: 250.ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MuscleGroupSection extends StatelessWidget {
  const _MuscleGroupSection({
    required this.group,
    required this.exercises,
    required this.onSelect,
  });

  final MuscleGroup group;
  final List<Exercise> exercises;
  final void Function(Exercise) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: PastelCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: group.color, shape: BoxShape.circle),
                    child: Icon(group.icon, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(group.label, style: AppTextStyles.heading),
                ],
              ),
            ),
            for (final e in exercises)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(e),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(e.name, style: AppTextStyles.body)),
                        const Icon(PhosphorIconsRegular.plus,
                            size: 18, color: AppColors.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
