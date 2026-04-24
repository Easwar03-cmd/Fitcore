import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../models/coach_listing.dart';
import '../providers/marketplace_provider.dart';

class CoachProfileScreen extends ConsumerWidget {
  const CoachProfileScreen({super.key, required this.coach});

  final CoachListing coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketAsync = ref.watch(marketplaceProvider);
    final hasRequest = marketAsync.valueOrNull?.hasActiveRequestFor(coach.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(coach.displayName,
            style: AppTextStyles.titleLarge
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // ── Header card ────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _CoachAvatar(name: coach.displayName, radius: 36),
                const SizedBox(height: 14),
                Text(coach.displayName,
                    style: AppTextStyles.titleLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _RatingRow(coach: coach),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: coach.specializations
                      .map((s) => _SpecChip(spec: s))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatPill(
                      icon: Icons.access_time_rounded,
                      label: 'Experience',
                      value: '${coach.yearsExp} yrs',
                    ),
                    _StatPill(
                      icon: Icons.attach_money_rounded,
                      label: 'Rate',
                      value: '\$${coach.hourlyRateUsd}/hr',
                      valueColor: AppColors.primary,
                    ),
                    _StatPill(
                      icon: Icons.rate_review_rounded,
                      label: 'Reviews',
                      value: '${coach.reviewCount}',
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),

          const SizedBox(height: 14),

          // ── About ──────────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text(coach.bio,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.5)),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.06, end: 0),

          if (coach.certifications != null &&
              coach.certifications!.isNotEmpty) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Certifications',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: coach.certifications!
                        .split(',')
                        .map((c) => c.trim())
                        .where((c) => c.isNotEmpty)
                        .map((c) => _CertChip(label: c))
                        .toList(),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 160.ms).slideY(begin: 0.06, end: 0),
          ],

          const SizedBox(height: 24),

          // ── CTA ────────────────────────────────────────────────────────
          if (hasRequest)
            _RequestedBanner()
          else
            FilledButton.icon(
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Request a Session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _showRequestSheet(context, ref),
            ),
        ],
      ),
    );
  }

  void _showRequestSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RequestSheet(coach: coach, ref: ref),
    );
  }
}

// ── Rating row ────────────────────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.coach});
  final CoachListing coach;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(5, (i) {
          final filled = i < coach.rating.floor();
          final half = !filled && i < coach.rating;
          return Icon(
            half ? Icons.star_half_rounded : Icons.star_rounded,
            color: filled || half
                ? AppColors.warning
                : Theme.of(context).colorScheme.onSurface.withAlpha(40),
            size: 18,
          );
        }),
        const SizedBox(width: 6),
        Text(
          '${coach.rating.toStringAsFixed(1)} · ${coach.reviewCount} reviews',
          style: AppTextStyles.bodySmall
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Stat pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(value,
            style: AppTextStyles.labelLarge.copyWith(
                color: valueColor ?? cs.onSurface,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ── Spec chip ─────────────────────────────────────────────────────────────────

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.spec});
  final String spec;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          specLabel(spec),
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
        ),
      );
}

// ── Cert chip ─────────────────────────────────────────────────────────────────

class _CertChip extends StatelessWidget {
  const _CertChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      );
}

// ── Already requested banner ──────────────────────────────────────────────────

class _RequestedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Session request sent — the coach will be in touch soon.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coach avatar ──────────────────────────────────────────────────────────────

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({required this.name, this.radius = 26});
  final String name;
  final double radius;

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
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: _color.withAlpha(40),
        child: Text(_initials,
            style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.55)),
      );
}

// ── Request sheet ─────────────────────────────────────────────────────────────

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.coach, required this.ref});
  final CoachListing coach;
  final WidgetRef ref;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSend => _ctrl.text.trim().length >= 10 && !_loading;

  Future<void> _send() async {
    setState(() => _loading = true);
    final ok = await widget.ref
        .read(marketplaceProvider.notifier)
        .sendRequest(widget.coach.id, _ctrl.text.trim());
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Request sent! ${widget.coach.displayName} will be in touch soon.'
          : 'Failed to send request — please try again.'),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Request a Session',
              style: AppTextStyles.titleLarge.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Tell ${widget.coach.displayName} about your goals and what you\'re looking for.',
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            maxLength: 1000,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'e.g. "I\'m looking to improve my squat form and build a 3-day strength programme..."',
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _canSend ? _send : null,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Request',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
