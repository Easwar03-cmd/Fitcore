import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_widgets.dart';

class ActivityLevelScreen extends ConsumerStatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  ConsumerState<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends ConsumerState<ActivityLevelScreen> {
  String? _selected;
  bool _isLoading = false;
  String? _errorMessage;

  static const _levels = [
    _LevelOption(
      value: 'sedentary',
      label: 'Sedentary',
      description: 'Little or no exercise, desk job',
      icon: Icons.chair_outlined,
    ),
    _LevelOption(
      value: 'light',
      label: 'Lightly Active',
      description: 'Light exercise 1–3 days per week',
      icon: Icons.directions_walk_rounded,
    ),
    _LevelOption(
      value: 'moderate',
      label: 'Moderately Active',
      description: 'Moderate exercise 3–5 days per week',
      icon: Icons.directions_bike_outlined,
    ),
    _LevelOption(
      value: 'active',
      label: 'Active',
      description: 'Hard exercise 6–7 days per week',
      icon: Icons.fitness_center_rounded,
    ),
    _LevelOption(
      value: 'very_active',
      label: 'Very Active',
      description: 'Hard daily exercise and physical job',
      icon: Icons.electric_bolt_rounded,
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
              const OnboardingStepBar(current: 3, total: 3),
              const SizedBox(height: 20),
              const OnboardingHeader(
                title: 'How active are you?',
                subtitle:
                    'Your activity level determines your daily calorie needs.',
                imageName: 'obj_dumbbell.png',
                fallbackIcon: Icons.fitness_center_rounded,
                tint: PastelTint.butter,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.salmon,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: _levels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final level = _levels[i];
                    final isSelected = _selected == level.value;
                    return OnboardingOptionCard(
                      icon: level.icon,
                      label: level.label,
                      description: level.description,
                      selected: isSelected,
                      onTap: _isLoading
                          ? null
                          : () => setState(() => _selected = level.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Finish Setup',
                onPressed: (_selected == null || _isLoading) ? null : _onSubmit,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back',
                variant: AppButtonVariant.ghost,
                onPressed: _isLoading ? null : () => context.go(AppRoutes.bodyStats),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(onboardingProvider.notifier).submit(_selected!);
      // markProfileComplete() inside submit() triggers RouterNotifier → /home
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}

class _LevelOption {
  const _LevelOption({
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

