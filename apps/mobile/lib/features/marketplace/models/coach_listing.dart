import 'package:flutter/foundation.dart';

@immutable
class CoachListing {
  const CoachListing({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.specializations,
    required this.hourlyRateUsd,
    required this.yearsExp,
    required this.rating,
    required this.reviewCount,
    this.certifications,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String bio;

  /// Raw comma-separated string from the API, split into a list.
  final List<String> specializations;
  final int hourlyRateUsd;
  final int yearsExp;
  final double rating;
  final int reviewCount;
  final String? certifications;
  final String? avatarUrl;

  factory CoachListing.fromJson(Map<String, dynamic> json) => CoachListing(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        bio: json['bio'] as String,
        specializations: (json['specializations'] as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        hourlyRateUsd: (json['hourlyRateUsd'] as num).toInt(),
        yearsExp: (json['yearsExp'] as num).toInt(),
        rating: (json['rating'] as num).toDouble(),
        reviewCount: (json['reviewCount'] as num).toInt(),
        certifications: json['certifications'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

/// Human-readable label for a specialization key.
String specLabel(String key) => switch (key) {
      'strength' => 'Strength',
      'cardio' => 'Cardio',
      'weight_loss' => 'Weight Loss',
      'nutrition' => 'Nutrition',
      'mobility' => 'Mobility',
      _ => key,
    };

@immutable
class SessionRequest {
  const SessionRequest({
    required this.id,
    required this.coachId,
    required this.status,
    required this.requestedAt,
  });

  final String id;
  final String coachId;
  final String status; // pending | accepted | declined
  final DateTime requestedAt;

  factory SessionRequest.fromJson(Map<String, dynamic> json) => SessionRequest(
        id: json['id'] as String,
        coachId: json['coachId'] as String,
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
      );
}

@immutable
class MarketplaceState {
  const MarketplaceState({
    required this.coaches,
    required this.myRequests,
    this.selectedSpec,
  });

  final List<CoachListing> coaches;
  final List<SessionRequest> myRequests;
  final String? selectedSpec; // null = All

  List<CoachListing> get filtered => selectedSpec == null
      ? coaches
      : coaches
          .where((c) => c.specializations.contains(selectedSpec))
          .toList();

  MarketplaceState copyWithSpec(String? spec) => MarketplaceState(
        coaches: coaches,
        myRequests: myRequests,
        selectedSpec: spec,
      );

  MarketplaceState copyWithRequest(SessionRequest req) => MarketplaceState(
        coaches: coaches,
        myRequests: [...myRequests, req],
        selectedSpec: selectedSpec,
      );

  bool hasActiveRequestFor(String coachId) => myRequests.any(
        (r) => r.coachId == coachId && r.status != 'declined',
      );
}
