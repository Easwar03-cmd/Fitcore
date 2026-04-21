import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/workout_recommendation.dart';

final _log = Logger();

enum WorkoutType { gym, home }

/// Family provider — one independent state per [WorkoutType].
/// Neither auto-fetches on build; call [generate()] explicitly.
final workoutRecommendationProvider = AsyncNotifierProvider.family<
    WorkoutRecommendationNotifier,
    WorkoutRecommendation?,
    WorkoutType>(WorkoutRecommendationNotifier.new);

class WorkoutRecommendationNotifier
    extends FamilyAsyncNotifier<WorkoutRecommendation?, WorkoutType> {
  @override
  Future<WorkoutRecommendation?> build(WorkoutType arg) async {
    ref.keepAlive();
    return null;
  }

  Future<void> generate() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<WorkoutRecommendation?> _fetch() async {
    final typeParam = arg == WorkoutType.home ? 'home' : 'gym';
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/ai/workout-recommendation?type=$typeParam');
      final data = response.data['data'] as Map<String, dynamic>;
      return WorkoutRecommendation.fromJson(data);
    } catch (e, st) {
      _log.w('Could not load $typeParam recommendation', error: e, stackTrace: st);
      rethrow;
    }
  }
}
