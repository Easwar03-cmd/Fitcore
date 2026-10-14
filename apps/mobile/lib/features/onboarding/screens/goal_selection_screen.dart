import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_widgets.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingStepBar(current: 1, total: 3),
              const SizedBox(height: 20),
              const OnboardingHeader(
                title: "What's your main goal?",
                subtitle:
                    'We use this to personalise your calorie target and workout plan.',
                imageName: 'obj_target.png',
                fallbackIcon: Icons.flag_rounded,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final goal = _goals[i];
                    final isSelected = _selected == goal.value;
                    return OnboardingOptionCard(
                      icon: goal.icon,
                      label: goal.label,
                      description: goal.description,
                      selected: isSelected,
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
