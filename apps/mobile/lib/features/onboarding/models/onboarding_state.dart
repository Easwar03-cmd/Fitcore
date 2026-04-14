/// Accumulates data across the 3 onboarding screens before submitting.
class OnboardingData {
  const OnboardingData({
    this.fitnessGoal,
    this.heightCm,
    this.weightKg,
    this.dateOfBirth,
    this.gender,
  });

  /// Backend values: lose_weight | build_muscle | maintain | endurance
  final String? fitnessGoal;
  final double? heightCm;
  final double? weightKg;
  final DateTime? dateOfBirth;

  /// Backend values: male | female | other | prefer_not_to_say
  final String? gender;

  OnboardingData copyWith({
    String? fitnessGoal,
    double? heightCm,
    double? weightKg,
    DateTime? dateOfBirth,
    String? gender,
  }) =>
      OnboardingData(
        fitnessGoal: fitnessGoal ?? this.fitnessGoal,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
      );
}
