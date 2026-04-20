import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/wearable_connection.dart';

final _log = Logger();

/// Map of connected provider names → connection info.
/// An empty map means no third-party wearables are connected.
final wearableProvider =
    AsyncNotifierProvider<WearableNotifier, Map<String, WearableConnection>>(
        WearableNotifier.new);

class WearableNotifier
    extends AsyncNotifier<Map<String, WearableConnection>> {
  @override
  Future<Map<String, WearableConnection>> build() => _fetch();

  Future<Map<String, WearableConnection>> _fetch() async {
    try {
      final res =
          await ref.read(apiClientProvider).dio.get('/integrations/status');
      final data = res.data['data'] as Map<String, dynamic>;
      return data.map(
        (provider, info) => MapEntry(
          provider,
          WearableConnection(
            provider: provider,
            connectedAt:
                DateTime.parse((info as Map<String, dynamic>)['connectedAt'] as String),
            updatedAt: DateTime.parse(info['updatedAt'] as String),
          ),
        ),
      );
    } on DioException catch (e, st) {
      _log.w('Failed to fetch wearable status', error: e, stackTrace: st);
      return {};
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Called after OAuth callback succeeds — optimistically marks the provider
  /// as connected without waiting for a full refresh.
  void markConnected(String provider) {
    final now = DateTime.now();
    final current = state.valueOrNull ?? {};
    state = AsyncData({
      ...current,
      provider: WearableConnection(
        provider: provider,
        connectedAt: now,
        updatedAt: now,
      ),
    });
  }

  /// Disconnect a provider (DELETE /integrations/:provider).
  Future<void> disconnect(String provider) async {
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .delete('/integrations/$provider');
      final current = Map<String, WearableConnection>.from(
          state.valueOrNull ?? {});
      current.remove(provider);
      state = AsyncData(current);
    } on DioException catch (e, st) {
      _log.e('Failed to disconnect $provider', error: e, stackTrace: st);
    }
  }
}
