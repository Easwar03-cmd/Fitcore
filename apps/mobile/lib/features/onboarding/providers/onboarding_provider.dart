import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/onboarding_state.dart';

class OnboardingNotifier extends Notifier<OnboardingData> {
  @override
  OnboardingData build() => const OnboardingData();

  void setGoal(String goal) {
    state = state.copyWith(fitnessGoal: goal);
  }

  void setBodyStats({
    required double heightCm,
    required double weightKg,
    required DateTime dateOfBirth,
    required String gender,
  }) {
    state = state.copyWith(
      heightCm: heightCm,
      weightKg: weightKg,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
  }

  /// Posts the full profile to the backend.
  /// [activityLevel] is one of: sedentary | light | moderate | active | very_active
  /// Throws on network/validation error so the calling screen can handle it.
  Future<void> submit(String activityLevel) async {
    final data = state;
    if (data.fitnessGoal == null ||
        data.heightCm == null ||
        data.weightKg == null ||
        data.dateOfBirth == null ||
        data.gender == null) {
      throw Exception('Onboarding data incomplete. Please go back and fill all fields.');
    }

    final dob = data.dateOfBirth!;
    final dobString =
        '${dob.year.toString().padLeft(4, '0')}-'
        '${dob.month.toString().padLeft(2, '0')}-'
        '${dob.day.toString().padLeft(2, '0')}';

    await ref.read(apiClientProvider).dio.post(
      '/user/profile',
      data: {
        'fitnessGoal': data.fitnessGoal,
        'activityLevel': activityLevel,
        'heightCm': data.heightCm,
        'weightKg': data.weightKg,
        'dateOfBirth': dobString,
        'gender': data.gender,
      },
    );

    // Update in-memory auth state so the router redirect fires to /home.
    ref.read(authProvider.notifier).markProfileComplete();
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingData>(OnboardingNotifier.new);
