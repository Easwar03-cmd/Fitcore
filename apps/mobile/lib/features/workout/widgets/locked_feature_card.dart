import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';

/// Shown in place of a Coach-gated feature section when the user is on Free/Pro.
class LockedFeatureCard extends StatelessWidget {
  const LockedFeatureCard({super.key, required this.featureName});

  final String featureName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const coachColor = Color(0xFFFF6B35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(AppRoutes.paywall, extra: featureName),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: coachColor.withValues(alpha: 0.12),
                  child: const Icon(Icons.lock_rounded,
                      color: coachColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(featureName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'Coach plan required — tap to upgrade',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: coachColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: coachColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Coach',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: coachColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
