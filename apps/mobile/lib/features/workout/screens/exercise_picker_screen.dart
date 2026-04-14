import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../models/exercise.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  String _query = '';

  Map<MuscleGroup, List<Exercise>> get _grouped {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? kExerciseLibrary
        : kExerciseLibrary
            .where((e) => e.name.toLowerCase().contains(q))
            .toList();

    final map = <MuscleGroup, List<Exercise>>{};
    for (final group in MuscleGroup.values) {
      final list = filtered.where((e) => e.muscleGroup == group).toList();
      if (list.isNotEmpty) map[group] = list;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? const Center(child: Text('No exercises found'))
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(group.icon, size: 14, color: group.color),
              const SizedBox(width: 6),
              Text(
                group.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: group.color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        ...exercises.map(
          (e) => ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: group.color.withValues(alpha: 0.12),
              child: Icon(group.icon, size: 16, color: group.color),
            ),
            title: Text(e.name),
            dense: true,
            onTap: () => onSelect(e),
          ),
        ),
      ],
    );
  }
}
