class SubscriptionInfo {
  const SubscriptionInfo({
    required this.tier,
    this.validUntil,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['validUntil'] as String?;
    return SubscriptionInfo(
      tier: (json['tier'] as String?) ?? 'free',
      validUntil: raw != null ? DateTime.tryParse(raw) : null,
    );
  }

  final String tier; // free | pro | coach
  final DateTime? validUntil;

  static const free = SubscriptionInfo(tier: 'free');

  bool get isActive => validUntil == null || validUntil!.isAfter(DateTime.now());
  bool get isPro => tier == 'pro' && isActive;
  bool get isCoach => tier == 'coach' && isActive;
  bool get isPaid => isPro || isCoach;

  // Coach-exclusive AI features
  bool get canUseAiWorkoutFeatures => isCoach;
}
