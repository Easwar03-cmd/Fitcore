import 'package:flutter/foundation.dart';

import '../../../core/services/health_service.dart';

// ── Mood log entry ─────────────────────────────────────────────────────────────

@immutable
class MoodLogEntry {
  const MoodLogEntry({required this.score, required this.loggedAt});

  final int score;      // 1-5
  final DateTime loggedAt;

  factory MoodLogEntry.fromJson(Map<String, dynamic> json) => MoodLogEntry(
        score: json['score'] as int,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

// ── Readiness level ────────────────────────────────────────────────────────────

enum ReadinessLevel { rest, light, hard }

// ── Wellness state ─────────────────────────────────────────────────────────────

@immutable
class WellnessState {
  const WellnessState({
    required this.sleepMinutes,
    this.sleepStages,
    required this.sleepScore,
    required this.sleepTrend,
    this.restingHr,
    required this.hrTrend,
    this.hrv,
    this.todayMood,
    required this.moodHistory,
    required this.readinessScore,
    required this.readinessLabel,
    required this.readinessLevel,
  });

  // ── Sleep ────────────────────────────────────────────────────────────────────
  /// Total minutes asleep last night.
  final int sleepMinutes;

  /// Breakdown into deep / light / REM. Null when device has no stage data.
  final SleepStages? sleepStages;

  /// 0-100 composite sleep quality score.
  final int sleepScore;

  /// Total sleep minutes for the past 7 nights, oldest first.
  final List<int> sleepTrend;

  // ── Heart rate & HRV ─────────────────────────────────────────────────────────
  /// Today's average resting HR in bpm. Null when no readings exist.
  final int? restingHr;

  /// Average HR for each of the past 7 days, oldest first. Null = no data.
  final List<int?> hrTrend;

  /// Today's average HRV in ms (SDNN). Null when no wearable data is available.
  final double? hrv;

  // ── Mood ─────────────────────────────────────────────────────────────────────
  /// Today's logged mood score (1-5). Null if not yet logged.
  final int? todayMood;

  /// Mood log entries for the past 14 days, oldest first.
  final List<MoodLogEntry> moodHistory;

  // ── Readiness ────────────────────────────────────────────────────────────────
  /// 0-100 composite readiness score.
  final int readinessScore;

  /// One-line recommendation text.
  final String readinessLabel;

  final ReadinessLevel readinessLevel;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String get sleepFormatted {
    final h = sleepMinutes ~/ 60;
    final m = sleepMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get hrZoneLabel {
    if (restingHr == null) return '—';
    final bpm = restingHr!;
    if (bpm < 50) return 'Athlete';
    if (bpm < 61) return 'Excellent';
    if (bpm < 71) return 'Good';
    if (bpm < 81) return 'Average';
    return 'Below average';
  }

  static const WellnessState empty = WellnessState(
    sleepMinutes: 0,
    sleepScore: 0,
    sleepTrend: [],
    hrTrend: [],
    moodHistory: [],
    readinessScore: 0,
    readinessLabel: '—',
    readinessLevel: ReadinessLevel.light,
  );

  WellnessState copyWithMood({
    required int todayMood,
    required List<MoodLogEntry> moodHistory,
  }) =>
      WellnessState(
        sleepMinutes: sleepMinutes,
        sleepStages: sleepStages,
        sleepScore: sleepScore,
        sleepTrend: sleepTrend,
        restingHr: restingHr,
        hrTrend: hrTrend,
        hrv: hrv,
        todayMood: todayMood,
        moodHistory: moodHistory,
        readinessScore: readinessScore,
        readinessLabel: readinessLabel,
        readinessLevel: readinessLevel,
      );
}
