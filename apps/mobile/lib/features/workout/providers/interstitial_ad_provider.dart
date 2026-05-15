import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';

import '../../subscription/providers/subscription_provider.dart';

final _log = Logger();

final interstitialAdProvider =
    StateNotifierProvider<InterstitialAdNotifier, bool>(
  (ref) => InterstitialAdNotifier(ref),
);

/// Manages the interstitial ad lifecycle: load → show → reload.
/// [state] is true when an ad is loaded and ready to show.
class InterstitialAdNotifier extends StateNotifier<bool> {
  InterstitialAdNotifier(this._ref) : super(false) {
    _load();
  }

  static const _adUnitId = 'ca-app-pub-3352385278044542/8100275469';

  final Ref _ref;
  InterstitialAd? _ad;

  void _load() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          if (mounted) state = true;
          _log.d('Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _log.w('Interstitial ad failed to load: ${error.message}');
          _ad = null;
          if (mounted) state = false;
        },
      ),
    );
  }

  /// Shows the interstitial if ready and the user is on the free tier, then
  /// calls [onComplete] when the ad closes (or immediately if not shown).
  void showIfReady(BuildContext context, VoidCallback onComplete) {
    final isPaid =
        _ref.read(subscriptionProvider).valueOrNull?.isPaid ?? false;

    if (isPaid || _ad == null || !state) {
      onComplete();
      return;
    }

    final ad = _ad!;
    _ad = null;
    state = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onComplete();
        _load(); // pre-load for next time
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _log.w('Interstitial failed to show: ${error.message}');
        ad.dispose();
        onComplete();
        _load();
      },
    );

    ad.show();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}
