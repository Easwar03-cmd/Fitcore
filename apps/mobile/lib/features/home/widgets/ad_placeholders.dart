import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';

import '../../subscription/providers/subscription_provider.dart';
import '../providers/ad_providers.dart';

final _log = Logger();

// ── Shared components ─────────────────────────────────────────────────────────

class _AdBadge extends StatelessWidget {
  const _AdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Ad',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Banner ad ─────────────────────────────────────────────────────────────────

/// Live 320×50 AdMob banner — sits between the AppBar and the CalorieRing.
/// Hidden for paid subscribers. Dismissible for the session via the X button.
/// Shows a slim shimmer skeleton while the ad is loading.
class AdBannerPlaceholder extends ConsumerStatefulWidget {
  const AdBannerPlaceholder({super.key});

  @override
  ConsumerState<AdBannerPlaceholder> createState() =>
      _AdBannerPlaceholderState();
}

class _AdBannerPlaceholderState extends ConsumerState<AdBannerPlaceholder> {
  static const _adUnitId = 'ca-app-pub-3352385278044542/3534344490';

  BannerAd? _ad;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          _log.w('Banner ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dismissed = ref.watch(adBannerDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    // No ads for paying subscribers.
    final isPaid =
        ref.watch(subscriptionProvider).valueOrNull?.isPaid ?? false;
    if (isPaid) return const SizedBox.shrink();

    // AdSize.banner is 320×50. We sit it in a 60px-tall container so there is
    // breathing room for the badge and close button without clipping the ad.
    final adW = _ad?.size.width.toDouble() ?? AdSize.banner.width.toDouble();
    final adH = _ad?.size.height.toDouble() ?? AdSize.banner.height.toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Skeleton shown while loading; replaced by AdWidget once ready.
            if (!_adLoaded) Positioned.fill(child: _BannerSkeleton()),
            if (_adLoaded && _ad != null)
              SizedBox(
                width: adW,
                height: adH,
                child: AdWidget(ad: _ad!),
              ),
            // "Ad" badge — top-left
            const Positioned(top: 4, left: 4, child: _AdBadge()),
            // Close button — top-right
            Positioned(
              top: 0,
              right: 0,
              child: _CloseButton(
                onTap: () =>
                    ref.read(adBannerDismissedProvider.notifier).state = true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(30),
        ),
      ),
    );
  }
}

// ── Popup ad ──────────────────────────────────────────────────────────────────

/// Live 180×100 AdMob banner — floats bottom-left of the home screen.
/// Appears after a 2-second delay on cold start (controlled by HomeScreen).
/// Hidden for paid subscribers. Dismissible for the session via the X button.
class AdPopupPlaceholder extends ConsumerStatefulWidget {
  const AdPopupPlaceholder({super.key});

  @override
  ConsumerState<AdPopupPlaceholder> createState() => _AdPopupPlaceholderState();
}

class _AdPopupPlaceholderState extends ConsumerState<AdPopupPlaceholder> {
  static const _adUnitId = 'ca-app-pub-3352385278044542/3099230221';
  static const _adSize = AdSize(width: 180, height: 100);

  BannerAd? _ad;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: _adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          _log.w('Popup ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dismissed = ref.watch(adPopupDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    // No ads for paying subscribers.
    final isPaid =
        ref.watch(subscriptionProvider).valueOrNull?.isPaid ?? false;
    if (isPaid) return const SizedBox.shrink();

    return SizedBox(
      width: 180,
      height: 100,
      child: Stack(
        children: [
          // Drop shadow behind the ad card.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          // Skeleton while loading; replaced by AdWidget once ready.
          if (!_adLoaded)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _BannerSkeleton(),
              ),
            ),
          if (_adLoaded && _ad != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _adSize.width.toDouble(),
                height: _adSize.height.toDouble(),
                child: AdWidget(ad: _ad!),
              ),
            ),
          // "Ad" badge — top-left
          const Positioned(top: 4, left: 4, child: _AdBadge()),
          // Close button — top-right
          Positioned(
            top: 0,
            right: 0,
            child: _CloseButton(
              onTap: () =>
                  ref.read(adPopupDismissedProvider.notifier).state = true,
            ),
          ),
        ],
      ),
    );
  }
}
