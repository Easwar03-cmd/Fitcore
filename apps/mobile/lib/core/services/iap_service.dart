import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

// Google Play subscription product IDs — must match exactly what is
// configured in Google Play Console under Subscriptions.
const kIapProductPro = 'revive_pro_monthly';
const kIapProductCoach = 'revive_coach_monthly';

final _log = Logger();

/// Thin wrapper around [InAppPurchase] for Google Play Billing.
/// Only used on Android; iOS subscriptions go through Stripe web checkout.
class IapService {
  static final InAppPurchase _iap = InAppPurchase.instance;

  static bool get isSupported => Platform.isAndroid;

  /// Query product details from the Play Store. Returns null if the store is
  /// unavailable or the query fails.
  static Future<List<ProductDetails>?> loadProducts() async {
    assert(Platform.isAndroid);
    final available = await _iap.isAvailable();
    if (!available) {
      _log.w('[IAP] Google Play Store not available');
      return null;
    }
    final response = await _iap.queryProductDetails(
      {kIapProductPro, kIapProductCoach},
    );
    if (response.error != null) {
      _log.e('[IAP] queryProductDetails error: ${response.error}');
      return null;
    }
    return response.productDetails;
  }

  /// Initiates a non-consumable (subscription) purchase via Google Play.
  /// The result arrives asynchronously on [purchaseStream].
  static Future<bool> initiatePurchase(ProductDetails product) {
    assert(Platform.isAndroid);
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// The stream of purchase updates from Google Play Billing.
  /// Listen to this during the lifetime of any screen that can trigger a
  /// purchase (e.g. PaywallScreen).
  static Stream<List<PurchaseDetails>> get purchaseStream =>
      _iap.purchaseStream;

  /// Must be called after every [PurchaseDetails] with status
  /// [PurchaseStatus.purchased] or [PurchaseStatus.restored] to acknowledge
  /// the purchase with Google Play. Failure to do so within 3 days causes an
  /// automatic refund.
  static Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}
