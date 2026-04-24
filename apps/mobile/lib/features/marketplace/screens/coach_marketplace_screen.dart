import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../models/coach_listing.dart';
import '../providers/marketplace_provider.dart';

// ── Specialization filter options ─────────────────────────────────────────────

const _kSpecs = [
  (null, 'All'),
  ('strength', 'Strength'),
  ('cardio', 'Cardio'),
  ('weight_loss', 'Weight Loss'),
  ('nutrition', 'Nutrition'),
  ('mobility', 'Mobility'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class CoachMarketplaceScreen extends ConsumerWidget {
  const CoachMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);
    final isCoach = subAsync.valueOrNull?.isCoach ?? false;

    if (!isCoach) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Coach Marketplace',
              style: AppTextStyles.titleLarge
                  .copyWith(color: Theme.of(context).colorScheme.onSurface)),
        ),
        body: _PaywallGate(
          onUpgrade: () => context.push(AppRoutes.paywall,
              extra: 'Coach marketplace'),
        ),
      );
    }

    final marketAsync = ref.watch(marketplaceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Coach Marketplace',
            style: AppTextStyles.titleLarge
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: marketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(marketplaceProvider.notifier).refresh(),
        ),
        data: (market) => _MarketplaceBrowser(market: market),
      ),
    );
  }
}

// ── Browser ───────────────────────────────────────────────────────────────────

class _MarketplaceBrowser extends ConsumerWidget {
  const _MarketplaceBrowser({required this.market});

  final MarketplaceState market;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = market.filtered;
    return RefreshIndicator(
      onRefresh: () => ref.read(marketplaceProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Spec filter chips ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _kSpecs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (key, label) = _kSpecs[i];
                  final selected = market.selectedSpec == key;
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(marketplaceProvider.notifier)
                        .setSpec(selected ? null : key),
                    selectedColor: AppColors.primary.withAlpha(40),
                    checkmarkColor: AppColors.primary,
                    labelStyle: AppTextStyles.labelLarge.copyWith(
                      color: selected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No coaches found for this specialisation.',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.separated(
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _CoachCard(
                  coach: filtered[i],
                  hasRequest: market.hasActiveRequestFor(filtered[i].id),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (i * 60).ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Coach card ────────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach, required this.hasRequest});

  final CoachListing coach;
  final bool hasRequest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              _CoachAvatar(name: coach.displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coach.displayName,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          coach.rating.toStringAsFixed(1),
                          style: AppTextStyles.labelSmall
                              .copyWith(color: cs.onSurface),
                        ),
                        Text(
                          ' (${coach.reviewCount})',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${coach.yearsExp}y exp',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${coach.hourlyRateUsd}',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800)),
                  Text('/hr',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Bio preview ─────────────────────────────────────────────────
          Text(
            coach.bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),

          // ── Spec chips ──────────────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: coach.specializations
                .map((s) => _SpecChip(spec: s))
                .toList(),
          ),
          const SizedBox(height: 12),

          // ── View Profile button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withAlpha(120)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => context.push(
                AppRoutes.coachProfile,
                extra: coach,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(hasRequest ? 'View Request' : 'View Profile'),
                  if (hasRequest) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Requested',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.success)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coach avatar initials ─────────────────────────────────────────────────────

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({required this.name});
  final String name;

  Color get _color {
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    const palette = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.info,
      AppColors.success,
      Color(0xFFFF6B35),
    ];
    return palette[hash % palette.length];
  }

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 26,
        backgroundColor: _color.withAlpha(40),
        child: Text(_initials,
            style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      );
}

// ── Spec chip ─────────────────────────────────────────────────────────────────

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.spec});
  final String spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        specLabel(spec),
        style: AppTextStyles.labelSmall
            .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Paywall gate ──────────────────────────────────────────────────────────────

class _PaywallGate extends StatelessWidget {
  const _PaywallGate({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded,
                  size: 48, color: Color(0xFFFF6B35)),
            ),
            const SizedBox(height: 20),
            Text('Coach Marketplace',
                style: AppTextStyles.titleLarge.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Browse certified fitness coaches and request 1-on-1 sessions. '
              'Available exclusively on the Coach plan.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Upgrade to Coach'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message.replaceFirst('Exception: ', ''),
              style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
