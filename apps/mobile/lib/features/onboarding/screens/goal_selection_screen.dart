import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class GoalSelectionScreen extends ConsumerStatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  ConsumerState<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends ConsumerState<GoalSelectionScreen> {
  String? _selected;

  static const _goals = [
    _GoalOption(
      value: 'lose_weight',
      label: 'Lose Weight',
      description: 'Burn fat and reach a healthy weight',
      icon: Icons.trending_down_rounded,
    ),
    _GoalOption(
      value: 'build_muscle',
      label: 'Build Muscle',
      description: 'Gain strength and increase muscle mass',
      icon: Icons.fitness_center_rounded,
    ),
    _GoalOption(
      value: 'maintain',
      label: 'Maintain Weight',
      description: 'Stay at your current weight and improve fitness',
      icon: Icons.balance_rounded,
    ),
    _GoalOption(
      value: 'endurance',
      label: 'Improve Endurance',
      description: 'Boost stamina and cardiovascular performance',
      icon: Icons.directions_run_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepIndicator(current: 1, total: 3),
              const SizedBox(height: 32),
              Text(
                "What's your main goal?",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'We use this to personalise your calorie target and workout plan.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final goal = _goals[i];
                    final isSelected = _selected == goal.value;
                    return _GoalCard(
                      option: goal,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selected = goal.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Continue',
                onPressed: _selected == null ? null : _onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onContinue() {
    ref.read(onboardingProvider.notifier).setGoal(_selected!);
    context.go(AppRoutes.bodyStats);
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _GoalOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(50)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.icon,
                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i + 1 <= current;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _GoalOption {
  const _GoalOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}
