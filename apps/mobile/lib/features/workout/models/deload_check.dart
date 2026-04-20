class DeloadCheck {
  const DeloadCheck({
    required this.needsDeload,
    required this.consecutiveHighVolumeWeeks,
    required this.weeklyAverageSets,
    required this.reason,
  });

  final bool needsDeload;
  final int consecutiveHighVolumeWeeks;
  final double weeklyAverageSets;
  final String reason;

  factory DeloadCheck.fromJson(Map<String, dynamic> json) => DeloadCheck(
        needsDeload: json['needsDeload'] as bool,
        consecutiveHighVolumeWeeks:
            (json['consecutiveHighVolumeWeeks'] as num).toInt(),
        weeklyAverageSets:
            (json['weeklyAverageSets'] as num).toDouble(),
        reason: json['reason'] as String,
      );
}
