import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class BodyStatsScreen extends ConsumerStatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  ConsumerState<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends ConsumerState<BodyStatsScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _dateOfBirth;
  String? _gender;

  static const _genders = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('other', 'Other'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepIndicator(current: 2, total: 3),
                const SizedBox(height: 32),
                Text(
                  'Your body stats',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Used to calculate your personalised calorie target.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),

                // Height
                TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    hintText: 'e.g. 175',
                    prefixIcon: Icon(Icons.height_rounded),
                    suffixText: 'cm',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,1}$')),
                  ],
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 50 || n > 300) {
                      return 'Enter a height between 50 and 300 cm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Weight
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'e.g. 75',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                    suffixText: 'kg',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,1}$')),
                  ],
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 20 || n > 500) {
                      return 'Enter a weight between 20 and 500 kg';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Date of birth
                FormField<DateTime>(
                  validator: (_) =>
                      _dateOfBirth == null ? 'Please select your date of birth' : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: const Icon(Icons.cake_outlined),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _dateOfBirth != null
                                ? '${_dateOfBirth!.day.toString().padLeft(2, '0')} / '
                                    '${_dateOfBirth!.month.toString().padLeft(2, '0')} / '
                                    '${_dateOfBirth!.year}'
                                : 'Tap to select',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: _dateOfBirth != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Gender
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: _genders
                      .map(
                        (g) => DropdownMenuItem(value: g.$1, child: Text(g.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? 'Please select a gender' : null,
                ),
                const SizedBox(height: 40),

                AppButton(label: 'Continue', onPressed: _onContinue),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Back',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go(AppRoutes.goalSelection),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _onContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(onboardingProvider.notifier).setBodyStats(
            heightCm: double.parse(_heightController.text),
            weightKg: double.parse(_weightController.text),
            dateOfBirth: _dateOfBirth!,
            gender: _gender!,
          );
      context.go(AppRoutes.activityLevel);
    }
  }
}

// ─── Step indicator (shared across onboarding screens) ───────────────────────

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
