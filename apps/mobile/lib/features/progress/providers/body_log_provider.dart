import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/sync_queue_service.dart' show syncServiceProvider;
import '../models/body_stat.dart';

final _log = Logger();

final bodyLogProvider =
    AsyncNotifierProvider<BodyLogNotifier, List<BodyStat>>(
        BodyLogNotifier.new);

class BodyLogNotifier extends AsyncNotifier<List<BodyStat>> {
  @override
  Future<List<BodyStat>> build() => _fetch();

  Future<List<BodyStat>> _fetch() async {
    try {
      final res = await ref.read(apiClientProvider).dio.get('/body/stats');
      final data = res.data['data'] as List<dynamic>;
      return data
          .map((e) => BodyStat.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e, st) {
      _log.e('Failed to load body stats', error: e, stackTrace: st);
      throw Exception('Failed to load body stats. Pull down to retry.');
    }
  }

  /// POST a new weight entry. Queues offline when there is no network.
  Future<void> logWeight({
    required double weightKg,
    double? bodyFatPct,
  }) async {
    final payload = <String, dynamic>{
      'weightKg': weightKg,
      if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
    };
    try {
      await ref.read(apiClientProvider).dio.post('/body/stats', data: payload);
      // Re-fetch to get the server-assigned id and measuredAt timestamp.
      state = await AsyncValue.guard(_fetch);
    } on DioException catch (e, st) {
      if (e.response == null) {
        await ref
            .read(syncServiceProvider)
            .enqueue('/body/stats', payload);
        _log.w('Body stat queued for sync (offline)', error: e);
        return;
      }
      _log.e('Failed to log body stat', error: e, stackTrace: st);
      throw Exception('Failed to save body stat. Please try again.');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
