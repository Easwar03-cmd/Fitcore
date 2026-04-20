import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/workout_recommendation.dart';

final _log = Logger();

final workoutRecommendationProvider =
    AsyncNotifierProvider<WorkoutRecommendationNotifier, WorkoutRecommendation?>(
        WorkoutRecommendationNotifier.new);

class WorkoutRecommendationNotifier
    extends AsyncNotifier<WorkoutRecommendation?> {
  @override
  Future<WorkoutRecommendation?> build() => _fetch();

  Future<WorkoutRecommendation?> _fetch() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/ai/workout-recommendation');
      final data = response.data['data'] as Map<String, dynamic>;
      return WorkoutRecommendation.fromJson(data);
    } catch (e, st) {
      _log.w('Could not load workout recommendation', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
