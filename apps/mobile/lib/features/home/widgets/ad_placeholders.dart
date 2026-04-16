import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/ad_providers.dart';

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
        child: const Icon(
          Icons.close_rounded,
          size: 16,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Banner ad placeholder ─────────────────────────────────────────────────────

/// Banner ad placeholder — sits between the AppBar and the CalorieRing.
///
/// Visual: rounded container (h=60, borderRadius=12) with a subtle gradient,
/// centred icon + "Advertisement" label, "Ad" pill badge top-left, X top-right.
///
/// TODO(admob): Replace this widget with AdWidget from the google_mobile_ads
/// package before launch. Create a BannerAd with AdSize.banner, call load(),
/// and dispose in the parent's dispose(). Keep the SizedBox height at 60.
class AdBannerPlaceholder extends ConsumerWidget {
  const AdBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(adBannerDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 60,
        child: Stack(
          children: [
            // Ad container
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceVariant,
                    AppColors.surfaceVariant.withAlpha(180),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.onSurfaceVariant.withAlpha(40),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 20,
                    color: AppColors.onSurfaceVariant,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Advertisement',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // "Ad" badge — top-left
            const Positioned(
              top: 6,
              left: 8,
              child: _AdBadge(),
            ),
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

// ── Popup ad placeholder ──────────────────────────────────────────────────────

/// Floating popup ad placeholder — rendered via Stack + Positioned at
/// bottom-left of the home screen. Appears after a 2-second delay on cold
/// start, controlled by the caller.
///
/// Visual: rounded card (w=180, h=100), shadow, "Ad" badge top-left, X top-right.
///
/// TODO(admob): Replace this widget with AdWidget from the google_mobile_ads
/// package before launch. Create a BannerAd with a custom 180×100 AdSize,
/// call load(), and dispose in the parent's dispose(). Keep the SizedBox
/// dimensions to avoid layout shifts.
class AdPopupPlaceholder extends ConsumerWidget {
  const AdPopupPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(adPopupDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    return SizedBox(
      width: 180,
      height: 100,
      child: Stack(
        children: [
          // Ad container
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.onSurfaceVariant.withAlpha(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 22,
                    color: AppColors.onSurfaceVariant,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Advertisement',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "Ad" badge — top-left
          const Positioned(
            top: 6,
            left: 8,
            child: _AdBadge(),
          ),
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
