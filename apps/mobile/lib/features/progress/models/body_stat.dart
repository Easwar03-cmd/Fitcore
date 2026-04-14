class BodyStat {
  const BodyStat({
    required this.id,
    required this.measuredAt,
    this.weightKg,
    this.bodyFatPct,
  });

  final String id;
  final DateTime measuredAt;
  final double? weightKg;
  final double? bodyFatPct;

  factory BodyStat.fromJson(Map<String, dynamic> json) => BodyStat(
        id: json['id'] as String,
        measuredAt: DateTime.parse(json['measuredAt'] as String),
        weightKg: json['weightKg'] != null
            ? (json['weightKg'] as num).toDouble()
            : null,
        bodyFatPct: json['bodyFatPct'] != null
            ? (json['bodyFatPct'] as num).toDouble()
            : null,
      );
}
