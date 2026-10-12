import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/report_ai_button.dart';
import '../models/workout_recommendation.dart';

/// Displays the AI-generated workout recommendation (sky metric card).
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onRefresh,
  });

  final WorkoutRecommendation recommendation;
  final VoidCallback onRefresh;

  PastelTint get _intensityTint => switch (recommendation.intensity) {
        'light' => PastelTint.lime,
        'hard' => PastelTint.salmon,
        _ => PastelTint.butter,
      };

  IconData get _intensityIcon => switch (recommendation.intensity) {
        'light' => PhosphorIconsRegular.batteryLow,
        'hard' => PhosphorIconsRegular.flame,
        _ => PhosphorIconsRegular.batteryMedium,
      };

  @override
  Widget build(BuildContext context) {
    final intensity = recommendation.intensity[0].toUpperCase() +
        recommendation.intensity.substring(1);

    return PastelCard(
      tint: PastelTint.sky,
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsRegular.sparkle, size: 18),
              const SizedBox(width: 6),
              Text('AI Recommendation', style: AppTextStyles.micro),
              const Spacer(),
              const ReportAiButton(
                  contentLabel: 'AI workout recommendation', size: 20),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(recommendation.workoutName,
                    style: AppTextStyles.metricM),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _intensityTint.color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_intensityIcon, size: 14),
                    const SizedBox(width: 4),
                    Text(intensity, style: AppTextStyles.micro),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(PhosphorIconsRegular.clock, size: 14),
              const SizedBox(width: 4),
              Text('~${recommendation.estimatedDurationMin} min',
                  style: AppTextStyles.caption.copyWith(color: AppColors.ink)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recommendation.targetMuscleGroups.join(' · '),
                  style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.reasoning,
            style: AppTextStyles.caption.copyWith(color: AppColors.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                for (final ex in recommendation.suggestedExercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(ex.name, style: AppTextStyles.bodyStrong),
                        ),
                        Text('${ex.sets} × ${ex.reps}',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
