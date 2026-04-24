import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/coach_listing.dart';

final _log = Logger();

class MarketplaceNotifier extends AsyncNotifier<MarketplaceState> {
  @override
  Future<MarketplaceState> build() async {
    if (ref.watch(authProvider).valueOrNull == null) {
      return const MarketplaceState(coaches: [], myRequests: []);
    }
    return _loadState();
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  void setSpec(String? spec) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWithSpec(spec));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadState);
  }

  /// Returns true on success, false on error (caller shows snackbar).
  Future<bool> sendRequest(String coachId, String message) async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post('/marketplace/request', data: {'coachId': coachId, 'message': message});
      final req = SessionRequest.fromJson(res.data['data'] as Map<String, dynamic>);
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current.copyWithRequest(req));
      }
      return true;
    } on DioException catch (e, st) {
      _log.e('Failed to send session request', error: e, stackTrace: st);
      return false;
    }
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<MarketplaceState> _loadState() async {
    final api = ref.read(apiClientProvider);
    final futures = await Future.wait([
      api.dio.get('/marketplace/coaches'),
      api.dio.get('/marketplace/my-requests'),
    ]);

    final coaches = (futures[0].data['data'] as List<dynamic>)
        .map((e) => CoachListing.fromJson(e as Map<String, dynamic>))
        .toList();

    final requests = (futures[1].data['data'] as List<dynamic>)
        .map((e) => SessionRequest.fromJson(e as Map<String, dynamic>))
        .toList();

    return MarketplaceState(coaches: coaches, myRequests: requests);
  }
}

final marketplaceProvider =
    AsyncNotifierProvider<MarketplaceNotifier, MarketplaceState>(
        MarketplaceNotifier.new);
