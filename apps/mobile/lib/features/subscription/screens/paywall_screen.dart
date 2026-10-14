import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/iap_service.dart';
import '../../../core/utils/regional_pricing.dart';
import '../providers/subscription_provider.dart';
import '../../../core/widgets/page_app_bar.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.highlightFeature});

  final String? highlightFeature;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  // ── Regional pricing (detected once from device locale) ───────────────────
  late final RegionalPricing _pricing = RegionalPricing.detect();

  // ── Stripe / iOS state ────────────────────────────────────────────────────
  bool _loadingPro = false;
  bool _loadingCoach = false;

  // ── Google Play / Android state ───────────────────────────────────────────
  bool _iapLoading = true;
  bool _purchaseProcessing = false;
  List<ProductDetails> _products = [];
  String? _iapError;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _purchaseSub = IapService.purchaseStream.listen(_onPurchaseUpdate);
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ── Google Play helpers ───────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    final products = await IapService.loadProducts();
    if (!mounted) return;
    setState(() {
      _iapLoading = false;
      if (products == null || products.isEmpty) {
        _iapError = 'Could not load prices from Google Play. Try again.';
      } else {
        _products = products;
      }
    });
  }

  Future<void> _purchaseWithGooglePlay(String tier) async {
    final productId = tier == 'pro' ? kIapProductPro : kIapProductCoach;
    final matches = _products.where((p) => p.id == productId);
    if (matches.isEmpty) {
      // Prices didn't load — say so and retry instead of a silent no-op tap.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Google Play is unavailable right now. Retrying — please try again in a moment.'),
        ),
      );
      setState(() {
        _iapError = null;
        _iapLoading = true;
      });
      await _loadProducts();
      return;
    }
    final product = matches.first;

    setState(() => _purchaseProcessing = true);
    try {
      await IapService.initiatePurchase(product);
      // Result arrives on _onPurchaseUpdate — do not set processing=false here.
    } catch (e) {
      if (mounted) {
        setState(() => _purchaseProcessing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not start purchase: $e')));
      }
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await ref
                .read(subscriptionProvider.notifier)
                .verifyGooglePlayPurchase(
                  purchaseToken:
                      purchase.verificationData.serverVerificationData,
                  productId: purchase.productID,
                );
            await IapService.completePurchase(purchase);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Purchase recorded but verification failed. Contact support.')),
              );
            }
          }
          if (mounted) setState(() => _purchaseProcessing = false);

        case PurchaseStatus.error:
          await IapService.completePurchase(purchase);
          if (mounted) {
            setState(() => _purchaseProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      purchase.error?.message ?? 'Purchase failed. Try again.')),
            );
          }

        case PurchaseStatus.canceled:
          if (mounted) setState(() => _purchaseProcessing = false);

        case PurchaseStatus.pending:
          break;
      }
    }
  }

  // ── Stripe / iOS helpers ──────────────────────────────────────────────────

  Future<void> _upgradeWithStripe(String tier) async {
    setState(() {
      if (tier == 'pro') {
        _loadingPro = true;
      } else {
        _loadingCoach = true;
      }
    });
    try {
      final url = await ref
          .read(subscriptionProvider.notifier)
          .createCheckoutUrl(tier, locale: _pricing.stripeLocale);
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        await ref.read(subscriptionProvider.notifier).refresh();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = (e.response?.data as Map?)?['error']?['message'] as String? ??
          'Server error. Try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open checkout: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingPro = false;
          _loadingCoach = false;
        });
      }
    }
  }

  // ── Unified upgrade dispatcher ────────────────────────────────────────────

  void _upgrade(String tier) {
    if (Platform.isAndroid) {
      _purchaseWithGooglePlay(tier);
    } else {
      _upgradeWithStripe(tier);
    }
  }

  // ── Price label helper ────────────────────────────────────────────────────

  String _priceFor(String productId) {
    // Android: Google Play returns a locale-formatted price natively.
    if (Platform.isAndroid) {
      if (_iapLoading) return '...';
      try {
        return _products.firstWhere((p) => p.id == productId).price;
      } catch (_) {
        return productId == kIapProductPro
            ? _pricing.proDisplay
            : _pricing.coachDisplay;
      }
    }
    // iOS / other: use the detected regional pricing.
    return productId == kIapProductPro
        ? _pricing.proDisplay
        : _pricing.coachDisplay;
  }

  bool get _anyLoading =>
      _loadingPro || _loadingCoach || _purchaseProcessing;

  bool get _proLoading =>
      _loadingPro || (_purchaseProcessing);

  bool get _coachLoading =>
      _loadingCoach || (_purchaseProcessing);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentTier =
        ref.watch(subscriptionProvider).valueOrNull?.tier ?? 'free';

    return Scaffold(
      appBar: const PageAppBar(title: 'Upgrade Revive'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.highlightFeature != null) ...[
              _LockedBanner(feature: widget.highlightFeature!),
              const SizedBox(height: 20),
            ],

            // IAP load error banner (Android only)
            if (Platform.isAndroid && _iapError != null) ...[
              PastelCard(
                tint: PastelTint.salmon,
                radius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_iapError!)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _iapError = null;
                          _iapLoading = true;
                        });
                        _loadProducts();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Semantics(
              header: true,
              child: Text('Choose your plan', style: AppTextStyles.display),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 4),
            Text(
              'Unlock the full Revive experience',
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 24),

            // Free tier
            _TierCard(
              tier: 'Free',
              price: '\$0',
              color: AppColors.surfaceMuted,
              isCurrent: currentTier == 'free',
              features: const [
                _Feature('Calorie & macro tracking', true),
                _Feature('Workout logging', true),
                _Feature('Basic progress charts', true),
                _Feature('Contains ads', true),
                _Feature('AI meal plans', false),
                _Feature('Food photo logging', false),
                _Feature('Advanced analytics', false),
                _Feature('Full wearable sync', false),
                _Feature('AI workout recommendations', false),
              ],
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideY(begin: 0.04, end: 0),

            const SizedBox(height: 16),

            // Pro tier
            _TierCard(
              tier: 'Pro',
              price: _priceFor(kIapProductPro),
              period: '/mo',
              color: AppColors.sky,
              badge: 'Most popular',
              isCurrent: currentTier == 'pro',
              features: const [
                _Feature('Everything in Free', true),
                _Feature('Ad-free experience', true),
                _Feature('AI meal plans (weekly)', true),
                _Feature('Food photo logging', true),
                _Feature('Advanced analytics', true),
                _Feature('Full wearable sync', true),
                _Feature('AI workout recommendations', false),
              ],
              cta: currentTier == 'pro'
                  ? null
                  : _proLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          currentTier == 'coach' ? 'Switch to Pro' : 'Upgrade to Pro',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: currentTier == 'pro' || _anyLoading || _iapLoading
                  ? null
                  : () => _upgrade('pro'),
            ).animate().fadeIn(delay: 250.ms, duration: 300.ms).slideY(begin: 0.04, end: 0),

            const SizedBox(height: 16),

            // Coach tier
            _TierCard(
              tier: 'Coach',
              price: _priceFor(kIapProductCoach),
              period: '/mo',
              color: AppColors.butter,
              isCurrent: currentTier == 'coach',
              features: const [
                _Feature('Everything in Pro', true),
                _Feature('AI workout recommendations', true),
                _Feature('Priority support', true),
              ],
              cta: currentTier == 'coach'
                  ? null
                  : _coachLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          currentTier == 'pro' ? 'Switch to Coach' : 'Upgrade to Coach',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: currentTier == 'coach' || _anyLoading || _iapLoading
                  ? null
                  : () => _upgrade('coach'),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms).slideY(begin: 0.04, end: 0),

            const SizedBox(height: 24),
            Text(
              Platform.isAndroid
                  ? 'Subscriptions are managed through Google Play. Cancel any time in Play Store > Subscriptions.'
                  : 'Cancel any time from your subscription settings. Secure payments via Stripe.',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.45)),
              textAlign: TextAlign.center,
            ),
            if (_pricing.isApproximate) ...[
              const SizedBox(height: 8),
              Text(
                'Prices shown in ${_pricing.currencyCode} are approximate. '
                'Final amount is confirmed at checkout.',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.35)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Locked feature banner ────────────────────────────────────────────────────

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.butter,
      radius: 24,
      semanticLabel: '$feature requires a paid plan.',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsRegular.lock, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$feature requires a paid plan.',
                style: AppTextStyles.bodyStrong),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _Feature {
  const _Feature(this.label, this.included);
  final String label;
  final bool included;
}

// ─── Tier card ────────────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.price,
    required this.color,
    required this.features,
    this.period,
    this.badge,
    this.cta,
    this.onTap,
    this.isCurrent = false,
  });

  final String tier;
  final String price;
  final String? period;

  /// Pastel tint of the whole card.
  final Color color;
  final String? badge;
  final List<_Feature> features;
  final Widget? cta;
  final VoidCallback? onTap;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$tier plan, $price${period ?? ''}${isCurrent ? ', current plan' : ''}',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(tier, style: AppTextStyles.title.copyWith(fontSize: 24)),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  PastelChip(label: badge!, filled: true),
                ],
                const Spacer(),
                Text(price, style: AppTextStyles.metricL),
                if (period != null && price != '...')
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Text(period!, style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (final f in features)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: f.included
                                  ? AppColors.lime
                                  : AppColors.surfaceMuted,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              f.included
                                  ? PhosphorIconsBold.check
                                  : PhosphorIconsBold.x,
                              size: 12,
                              color: f.included
                                  ? AppColors.ink
                                  : AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              f.label,
                              style: AppTextStyles.body.copyWith(
                                color: f.included
                                    ? AppColors.ink
                                    : AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (cta != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onTap, child: cta),
            ],
            if (isCurrent) ...[
              const SizedBox(height: 12),
              Text(
                'Your current plan',
                style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
