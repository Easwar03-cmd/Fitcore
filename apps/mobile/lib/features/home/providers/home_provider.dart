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
    // Capture userId synchronously here — BEFORE any async gaps — so that
    // _loadState() never evaluates it mid-flight when authProvider might still
    // be AsyncLoading (which would produce 'anonymous' and read the wrong key).
    final authState = ref.watch(authProvider);
    final userId = authState.valueOrNull?.user.id ?? 'anonymous';
    return _loadState(userId: userId);
  }

  // Keep _userId for action methods called from the UI (auth is always loaded
  // by the time the user interacts with buttons).
  String get _userId =>
      ref.read(authProvider).valueOrNull?.user.id ?? 'anonymous';

  // ── Public actions ─────────────────────────────────────────────────────────

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
    final uid = _userId;
    final newMl = current.waterMl + ml;
    state = AsyncData(current.copyWith(waterMl: newMl));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterKey(uid), newMl);
  }

  Future<void> updateStreakForToday({required bool hasLogs}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    final (streak, graceUsed) =
        _computeAndSaveStreak(prefs, _userId, hasLogs: hasLogs);
    state = AsyncData(current.copyWith(streak: streak, graceUsed: graceUsed));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => _loadState(userId: _userId));
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<HomeDashboardState> _loadState({required String userId}) async {
    final profileFuture = _fetchProfile();
    final stepsFuture = ref.read(healthServiceProvider).getTodaySteps();

    final profile = await profileFuture;
    final steps = await stepsFuture;

    // userId is already captured before any async gap — always correct.
    final prefs = await SharedPreferences.getInstance();
    final waterMl = prefs.getInt(_waterKey(userId)) ?? 0;
    final caloriesBurnedToday = prefs.getInt(_burnedKey(userId)) ?? 0;
    final streak = prefs.getInt('${_kStreakCount}_$userId') ?? 0;
    final graceAvail = prefs.getBool('${_kStreakGraceAvail}_$userId') ?? true;

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
      _log.e('Failed to fetch user profile — using TDEE fallback',
          error: e, stackTrace: st);
      return UserProfileDto.fallback;
    }
  }

  (int, bool) _computeAndSaveStreak(
    SharedPreferences prefs,
    String userId, {
    required bool hasLogs,
  }) {
    final today = _todayStr();
    final lastDate = prefs.getString('${_kStreakLastDate}_$userId') ?? '';
    var streak = prefs.getInt('${_kStreakCount}_$userId') ?? 0;
    var graceAvail = prefs.getBool('${_kStreakGraceAvail}_$userId') ?? true;

    if (lastDate == today) return (streak, !graceAvail);
    if (!hasLogs) return (streak, !graceAvail);

    final yesterday =
        _dateStr(DateTime.now().subtract(const Duration(days: 1)));
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

  static String _waterKey(String userId) =>
      '$_kWaterBase${userId}_${_todayStr()}';
  static String _burnedKey(String userId) =>
      '$_kBurnedBase${userId}_${_todayStr()}';

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String _dateStr(DateTime dt) => '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

final homeProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboardState>(
        HomeDashboardNotifier.new);
