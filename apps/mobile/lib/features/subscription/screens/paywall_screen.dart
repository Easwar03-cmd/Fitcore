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
    final product = _products.firstWhere(
      (p) => p.id == (tier == 'pro' ? kIapProductPro : kIapProductCoach),
      orElse: () => throw StateError('Product not loaded'),
    );

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
      appBar: AppBar(title: const Text('Upgrade Revive')),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        color: cs.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_iapError!,
                          style: TextStyle(color: cs.onErrorContainer)),
                    ),
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

            Text(
              'Choose your plan',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 4),
            Text(
              'Unlock the full Revive experience',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 24),

            // Free tier
            _TierCard(
              tier: 'Free',
              price: '\$0',
              color: cs.surfaceContainerHighest,
              labelColor: cs.onSurface,
              isCurrent: currentTier == 'free',
              features: const [
                _Feature('Calorie & macro tracking', true),
                _Feature('Workout logging', true),
                _Feature('Basic progress charts', true),
                _Feature('AI coach (5 msg/day)', true),
                _Feature('Contains ads', true),
                _Feature('AI meal plans', false),
                _Feature('Food photo logging', false),
                _Feature('Advanced analytics', false),
                _Feature('Full wearable sync', false),
                _Feature('AI workout recommendations', false),
                _Feature('AI Form Monitor', false),
              ],
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideY(begin: 0.04, end: 0),

            const SizedBox(height: 16),

            // Pro tier
            _TierCard(
              tier: 'Pro',
              price: _priceFor(kIapProductPro),
              period: '/mo',
              color: const Color(0xFF6C63FF),
              labelColor: Colors.white,
              badge: 'Most popular',
              isCurrent: currentTier == 'pro',
              features: const [
                _Feature('Everything in Free', true),
                _Feature('Ad-free experience', true),
                _Feature('Unlimited AI coach', true),
                _Feature('AI meal plans (weekly)', true),
                _Feature('Food photo logging', true),
                _Feature('Advanced analytics', true),
                _Feature('Full wearable sync', true),
                _Feature('AI workout recommendations', false),
                _Feature('AI Form Monitor (Beta)', false),
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
              color: const Color(0xFFFF6B35),
              labelColor: Colors.white,
              isCurrent: currentTier == 'coach',
              features: const [
                _Feature('Everything in Pro', true),
                _Feature('AI workout recommendations', true),
                _Feature('AI Form Monitor (Beta)', true),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$feature requires a paid plan.',
              style: TextStyle(
                  color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
            ),
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
    required this.labelColor,
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
  final Color color;
  final Color labelColor;
  final String? badge;
  final List<_Feature> features;
  final Widget? cta;
  final VoidCallback? onTap;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Text(
                  tier,
                  style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800, color: color),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const Spacer(),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800, color: color),
                      ),
                      if (period != null && price != '...')
                        TextSpan(
                          text: period,
                          style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                for (final f in features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          f.included
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 18,
                          color: f.included
                              ? color
                              : cs.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          f.label,
                          style: tt.bodyMedium?.copyWith(
                            color: f.included
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (cta != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: labelColor,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onTap,
                      child: cta,
                    ),
                  ),
                ],
                if (isCurrent) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Your current plan',
                    style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
