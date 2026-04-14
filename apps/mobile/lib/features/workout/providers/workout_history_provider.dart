import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/workout_log.dart';

final _log = Logger();

final workoutHistoryProvider =
    AsyncNotifierProvider<WorkoutHistoryNotifier, List<WorkoutLog>>(
        WorkoutHistoryNotifier.new);

class WorkoutHistoryNotifier extends AsyncNotifier<List<WorkoutLog>> {
  @override
  Future<List<WorkoutLog>> build() => _fetch();

  Future<List<WorkoutLog>> _fetch() async {
    try {
      final res =
          await ref.read(apiClientProvider).dio.get('/workout/logs');
      final data = res.data['data'] as List<dynamic>;
      return data
          .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, st) {
      _log.e('Failed to load workout history', error: e, stackTrace: st);
      throw Exception('Failed to load workout history. Pull down to retry.');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
