import 'package:flutter/material.dart';

import '../models/workout_recommendation.dart';

/// Displays the AI-generated workout recommendation on the Workout tab.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onRefresh,
  });

  final WorkoutRecommendation recommendation;
  final VoidCallback onRefresh;

  Color _intensityColor(BuildContext context) => switch (recommendation.intensity) {
        'light' => const Color(0xFF38A169),
        'hard' => const Color(0xFFE53E3E),
        _ => const Color(0xFFD69E2E),
      };

  IconData _intensityIcon() => switch (recommendation.intensity) {
        'light' => Icons.battery_1_bar_rounded,
        'hard' => Icons.local_fire_department_rounded,
        _ => Icons.battery_4_bar_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iColor = _intensityColor(context);

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 18),
                const SizedBox(width: 6),
                Text(
                  'AI Recommendation',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Workout name + intensity ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    recommendation.workoutName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: iColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_intensityIcon(), size: 14, color: iColor),
                      const SizedBox(width: 4),
                      Text(
                        recommendation.intensity[0].toUpperCase() +
                            recommendation.intensity.substring(1),
                        style: TextStyle(
                            fontSize: 12,
                            color: iColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Meta row: duration + muscle groups ─────────────────────────
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '~${recommendation.estimatedDurationMin} min',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation.targetMuscleGroups.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Reasoning ─────────────────────────────────────────────────
            Text(
              recommendation.reasoning,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Exercise list ──────────────────────────────────────────────
            ...recommendation.suggestedExercises.map(
              (ex) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ex.name,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${ex.sets} × ${ex.reps}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
