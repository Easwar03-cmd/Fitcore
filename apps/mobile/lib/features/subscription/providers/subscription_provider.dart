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

  /// Sends a Google Play purchase token to the backend for server-side
  /// verification. On success, re-fetches the subscription so the UI updates.
  Future<void> verifyGooglePlayPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    await ref.read(apiClientProvider).dio.post(
      '/payments/google-play/verify',
      data: {'purchaseToken': purchaseToken, 'productId': productId},
    );
    ref.invalidateSelf();
    await future;
  }

  /// Returns the Stripe checkout URL for the given tier ('pro' or 'coach').
  /// Passes the device locale so Stripe presents the checkout in the user's
  /// language and local currency (requires Adaptive Pricing enabled in Stripe).
  Future<String> createCheckoutUrl(String tier, {String? locale}) async {
    final res = await ref.read(apiClientProvider).dio.post(
      '/payments/checkout',
      data: {
        'tier': tier,
        if (locale != null) 'locale': locale,
      },
    );
    return res.data['data']['url'] as String;
  }

  /// Returns the Stripe billing portal URL. Used on iOS.
  Future<String> createPortalUrl() async {
    final res =
        await ref.read(apiClientProvider).dio.post('/payments/portal');
    return res.data['data']['url'] as String;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
