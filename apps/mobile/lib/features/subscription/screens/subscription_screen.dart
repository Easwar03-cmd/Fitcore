import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_routes.dart';
import '../../../core/services/iap_service.dart';
import '../models/subscription_info.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver {
  bool _openingPortal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(subscriptionProvider.notifier).refresh();
    }
  }

  // Opens the appropriate subscription management UI for the current platform.
  Future<void> _openManageBilling(SubscriptionInfo sub) async {
    setState(() => _openingPortal = true);
    try {
      if (Platform.isAndroid) {
        final productId =
            sub.isCoach ? kIapProductCoach : kIapProductPro;
        final uri = Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?sku=$productId&package=com.revive.app',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final url =
            await ref.read(subscriptionProvider.notifier).createPortalUrl();
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open billing portal. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingPortal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: subAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load subscription.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(subscriptionProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (sub) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _PlanBadge(sub: sub)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, end: 0),
            const SizedBox(height: 24),

            if (sub.validUntil != null) ...[
              _InfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Renews / expires',
                value: _formatDate(sub.validUntil!),
              ),
              const SizedBox(height: 8),
            ],

            _FeatureSummary(sub: sub),
            const SizedBox(height: 28),

            if (!sub.isPaid) ...[
              FilledButton.icon(
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Upgrade to Pro'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF6C63FF),
                ),
                onPressed: () => context.push(AppRoutes.paywall),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.military_tech_rounded),
                label: const Text('See all plans'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => context.push(AppRoutes.paywall),
              ),
            ] else ...[
              FilledButton.icon(
                icon: _openingPortal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Platform.isAndroid
                        ? Icons.shop_rounded
                        : Icons.open_in_new_rounded),
                label: Text(Platform.isAndroid
                    ? 'Manage on Google Play'
                    : 'Manage billing'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _openingPortal ? null : () => _openManageBilling(sub),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Switch / compare plans'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => context.push(AppRoutes.paywall),
              ),
              const SizedBox(height: 12),
              Text(
                Platform.isAndroid
                    ? 'To cancel or update payment method, tap "Manage on Google Play".'
                    : 'Update payment method or cancel via "Manage billing". Switch tiers from the plans screen.',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ─── Plan badge ───────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.sub});
  final SubscriptionInfo sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (label, color) = switch (sub.tier) {
      'pro' => ('Pro', const Color(0xFF6C63FF)),
      'coach' => ('Coach', const Color(0xFFFF6B35)),
      _ => ('Free', cs.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: color, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current plan',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
              Text(label,
                  style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const Spacer(),
          if (sub.isPaid)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Active',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Text(label,
            style: tt.bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
        const Spacer(),
        Text(value,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Feature summary ──────────────────────────────────────────────────────────

class _FeatureSummary extends StatelessWidget {
  const _FeatureSummary({required this.sub});
  final SubscriptionInfo sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final features = sub.isPaid
        ? [
            'Ad-free experience',
            'Unlimited AI coach',
            'AI meal plans (weekly)',
            'Food photo logging',
            'Advanced analytics',
            'Full wearable sync',
            if (sub.isCoach) 'AI workout recommendations',
            if (sub.isCoach) 'AI Form Monitor (Beta)',
          ]
        : ['Calorie & macro tracking', 'Workout logging', 'AI coach (5/day)', 'Contains ads'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Included features',
              style: tt.labelMedium
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 10),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(f, style: tt.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
