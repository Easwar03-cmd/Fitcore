import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/pose_feedback.dart';

/// Overlay card showing Gemini-generated coaching tips above the ML Kit
/// feedback card. Pulses a loading indicator while analysis is in flight.
class GeminiTipCard extends StatelessWidget {
  const GeminiTipCard({
    super.key,
    required this.tip,
    required this.isAnalyzing,
  });

  final GeminiFormFeedback? tip;
  final bool isAnalyzing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isAnalyzing && tip == null ? _buildLoading() : _buildContent(tip!),
    )
        .animate(key: ValueKey(isAnalyzing && tip == null))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.15, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }

  Widget _buildLoading() {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF818CF8),
          ),
        ),
        SizedBox(width: 10),
        Text(
          'AI coach analyzing your form...',
          style: TextStyle(
            color: Color(0xFF818CF8),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: const Color(0xFF818CF8));
  }

  Widget _buildContent(GeminiFormFeedback tip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 15),
            const SizedBox(width: 6),
            const Text(
              'AI Coach',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              tip.encouragement,
              style: const TextStyle(
                color: Color(0xFFA5B4FC),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        if (tip.tips.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...tip.tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.arrow_right_rounded,
                        color: Color(0xFF6366F1), size: 16),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
