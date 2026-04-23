import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/pose_feedback.dart';

/// Floating card at the bottom of the monitor screen.
/// Green checkmark = correct form. Amber/red = correction cue.
class FormFeedbackCard extends StatelessWidget {
  const FormFeedbackCard({
    super.key,
    required this.feedback,
    required this.repCount,
  });

  final PoseFeedback feedback;
  final int repCount;

  Color _bg(BuildContext context) => switch (feedback.level) {
        FeedbackLevel.none => const Color(0xFF1F2937),
        FeedbackLevel.good => const Color(0xFF166534),
        FeedbackLevel.warn => const Color(0xFF92400E),
        FeedbackLevel.error => const Color(0xFF991B1B),
      };

  Color _fg(BuildContext context) => switch (feedback.level) {
        FeedbackLevel.none => const Color(0xFF9CA3AF),
        FeedbackLevel.good => const Color(0xFF86EFAC),
        FeedbackLevel.warn => const Color(0xFFFDE68A),
        FeedbackLevel.error => const Color(0xFFFCA5A5),
      };

  IconData get _icon => switch (feedback.level) {
        FeedbackLevel.none => Icons.person_search_rounded,
        FeedbackLevel.good => Icons.check_circle_rounded,
        FeedbackLevel.warn => Icons.warning_amber_rounded,
        FeedbackLevel.error => Icons.cancel_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final bg = _bg(context);
    final fg = _fg(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feedback.message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (repCount > 0) ...[
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$repCount',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'reps',
                  style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate(key: ValueKey(feedback.level))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.2, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}
