/// Represents one connected third-party wearable provider returned by
/// GET /api/v1/integrations/status.
class WearableConnection {
  const WearableConnection({
    required this.provider,
    required this.connectedAt,
    required this.updatedAt,
  });

  /// e.g. 'fitbit', 'garmin', 'whoop', 'oura'
  final String provider;
  final DateTime connectedAt;
  final DateTime updatedAt;

  factory WearableConnection.fromJson(Map<String, dynamic> json) =>
      WearableConnection(
        provider: json['provider'] as String,
        connectedAt: DateTime.parse(json['connectedAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
