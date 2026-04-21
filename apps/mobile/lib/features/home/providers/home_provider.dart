import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/health_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/home_state.dart';

final _log = Logger();

// SharedPreferences key prefixes — always suffixed with userId so data
// never leaks between accounts on the same device.
const _kStreakCount = 'streak_count';
const _kStreakLastDate = 'streak_last_date'; // YYYY-MM-DD
const _kStreakGraceAvail = 'streak_grace_avail'; // bool: true = grace not yet used
const _kWaterBase = 'water_ml_'; // + userId + YYYY-MM-DD suffix
const _kBurnedBase = 'calories_burned_'; // + userId + YYYY-MM-DD suffix

class HomeDashboardNotifier extends AsyncNotifier<HomeDashboardState> {
  @override
  Future<HomeDashboardState> build() {
    // Watch authProvider so this rebuilds when the logged-in user changes.
    ref.watch(authProvider);
    return _loadState();
  }

  // Use ref.read in action methods — ref.watch is only valid inside build().
  String get _userId =>
      ref.read(authProvider).valueOrNull?.user.id ?? 'anonymous';

  // ── Public actions ─────────────────────────────────────────────────────────

  /// Adds [kcal] to today's burned-calorie total and persists it.
  /// Called by [WorkoutSessionNotifier] after a workout is successfully saved.
  Future<void> addBurnedCalories(int kcal) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final newTotal = current.caloriesBurnedToday + kcal;
    state = AsyncData(current.copyWith(caloriesBurnedToday: newTotal));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_burnedKey(_userId), newTotal);
  }

  Future<void> addWater(int ml) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final newMl = current.waterMl + ml;
    state = AsyncData(current.copyWith(waterMl: newMl));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterKey(_userId), newMl);
  }

  /// Called by HomeScreen once food logs are available so streak can be updated.
  Future<void> updateStreakForToday({required bool hasLogs}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    final (streak, graceUsed) = _computeAndSaveStreak(prefs, _userId, hasLogs: hasLogs);
    state = AsyncData(current.copyWith(streak: streak, graceUsed: graceUsed));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadState);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<HomeDashboardState> _loadState() async {
    // Kick off profile and steps fetches in parallel.
    final profileFuture = _fetchProfile();
    final stepsFuture = ref.read(healthServiceProvider).getTodaySteps();

    final profile = await profileFuture;
    final steps = await stepsFuture;

    final uid = _userId;
    final prefs = await SharedPreferences.getInstance();
    final waterMl = prefs.getInt(_waterKey(uid)) ?? 0;
    final caloriesBurnedToday = prefs.getInt(_burnedKey(uid)) ?? 0;
    // On initial load show the persisted streak; updateStreakForToday()
    // is called by HomeScreen once it sees whether there are food logs today.
    final streak = prefs.getInt('${_kStreakCount}_$uid') ?? 0;
    final graceAvail = prefs.getBool('${_kStreakGraceAvail}_$uid') ?? true;

    return HomeDashboardState(
      tdee: profile.tdee,
      fitnessGoal: profile.fitnessGoal,
      activityLevel: profile.activityLevel,
      weightKg: profile.weightKg,
      steps: steps,
      waterMl: waterMl,
      streak: streak,
      graceUsed: !graceAvail,
      caloriesBurnedToday: caloriesBurnedToday,
    );
  }

  Future<UserProfileDto> _fetchProfile() async {
    try {
      final res = await ref.read(apiClientProvider).dio.get('/user/profile');
      return UserProfileDto.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e, st) {
      _log.e('Failed to fetch user profile — using TDEE fallback', error: e, stackTrace: st);
      return UserProfileDto.fallback;
    }
  }

  /// Computes the new streak based on today's activity and persists to prefs.
  /// Returns (streakCount, graceUsed).
  (int, bool) _computeAndSaveStreak(
    SharedPreferences prefs,
    String userId, {
    required bool hasLogs,
  }) {
    final today = _todayStr();
    final lastDate = prefs.getString('${_kStreakLastDate}_$userId') ?? '';
    var streak = prefs.getInt('${_kStreakCount}_$userId') ?? 0;
    var graceAvail = prefs.getBool('${_kStreakGraceAvail}_$userId') ?? true;

    // Already processed today — nothing to change.
    if (lastDate == today) return (streak, !graceAvail);

    // Today doesn't qualify yet; keep existing streak display.
    if (!hasLogs) return (streak, !graceAvail);

    final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
    final twoDaysAgo =
        _dateStr(DateTime.now().subtract(const Duration(days: 2)));

    if (lastDate == yesterday) {
      streak++;
    } else if (lastDate == twoDaysAgo && graceAvail) {
      graceAvail = false;
    } else {
      streak = 1;
      graceAvail = true;
    }

    prefs.setInt('${_kStreakCount}_$userId', streak);
    prefs.setString('${_kStreakLastDate}_$userId', today);
    prefs.setBool('${_kStreakGraceAvail}_$userId', graceAvail);

    return (streak, !graceAvail);
  }

  static String _waterKey(String userId) => '$_kWaterBase${userId}_${_todayStr()}';
  static String _burnedKey(String userId) => '$_kBurnedBase${userId}_${_todayStr()}';

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

final homeProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboardState>(
        HomeDashboardNotifier.new);
