import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subscription_info.dart';

final _log = Logger();

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionInfo>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends AsyncNotifier<SubscriptionInfo> {
  @override
  Future<SubscriptionInfo> build() async {
    // Rebuild whenever the logged-in user changes.
    final auth = ref.watch(authProvider).valueOrNull;
    if (auth == null) return SubscriptionInfo.free;

    try {
      final res =
          await ref.read(apiClientProvider).dio.get('/payments/subscription');
      return SubscriptionInfo.fromJson(
          res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _log.w('Failed to fetch subscription', error: e);
      return SubscriptionInfo.free;
    }
  }

  // Returns the Stripe checkout URL for the given tier ('pro' or 'coach').
  Future<String> createCheckoutUrl(String tier) async {
    final res = await ref
        .read(apiClientProvider)
        .dio
        .post('/payments/checkout', data: {'tier': tier});
    return res.data['data']['url'] as String;
  }

  // Returns the Stripe billing portal URL.
  Future<String> createPortalUrl() async {
    final res =
        await ref.read(apiClientProvider).dio.post('/payments/portal');
    return res.data['data']['url'] as String;
  }

  // Re-fetch subscription status (call after returning from browser payment flow).
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
