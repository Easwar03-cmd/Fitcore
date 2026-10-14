import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/community_models.dart';
import '../providers/community_provider.dart';
import '../../../core/widgets/page_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/stat_card.dart';

/// Admin view of one member: fitness report + challenge progress, plus the
/// hold / resume / delete-record / remove actions.
class MemberReportScreen extends ConsumerWidget {
  const MemberReportScreen({
    super.key,
    required this.communityId,
    required this.userId,
  });

  final String communityId;
  final String userId;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String? success,
    bool popAfter = false,
  }) async {
    try {
      await action();
      if (!context.mounted) return;
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
      if (popAfter) context.pop();
    } on CommunityException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (communityId: communityId, userId: userId);
    final report = ref.watch(memberReportProvider(key));
    final members = ref.watch(communityMembersProvider(communityId));
    final actions = ref.read(communityActionsProvider);

    final member = members.valueOrNull
        ?.where((m) => m.userId == userId)
        .cast<CommunityMemberInfo?>()
        .firstWhere((_) => true, orElse: () => null);
    final status = member?.status;

    return Scaffold(
      appBar: PageAppBar(
        title: member?.name ?? 'Member',
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'hold':
                  await _run(context, () => actions.memberAction(communityId, userId, 'hold'),
                      success: 'Tracking paused. Data up to now is kept.');
                  ref.invalidate(memberReportProvider(key));
                case 'resume':
                  await _run(context, () => actions.memberAction(communityId, userId, 'resume'),
                      success: 'Tracking resumed from today.');
                  ref.invalidate(memberReportProvider(key));
                case 'delete':
                  if (await _confirm(
                    context,
                    'Delete tracking record?',
                    'This permanently removes everything you hold on this '
                        'member. It cannot be recovered.',
                    'Delete',
                  )) {
                    if (!context.mounted) return;
                    await _run(context, () => actions.deleteTrackingRecord(communityId, userId),
                        success: 'Tracking record deleted.');
                    ref.invalidate(memberReportProvider(key));
                  }
                case 'remove':
                  if (await _confirm(
                    context,
                    'Remove from community?',
                    'They will lose access to this community.',
                    'Remove',
                  )) {
                    if (!context.mounted) return;
                    await _run(context, () => actions.removeMember(communityId, userId),
                        popAfter: true);
                  }
              }
            },
            itemBuilder: (_) => [
              if (status == 'active')
                const PopupMenuItem(value: 'hold', child: Text('Put tracking on hold')),
              if (status == 'on_hold')
                const PopupMenuItem(value: 'resume', child: Text('Resume tracking')),
              const PopupMenuItem(value: 'delete', child: Text('Delete tracking record')),
              if (status != 'left')
                const PopupMenuItem(value: 'remove', child: Text('Remove from community')),
            ],
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              e.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (r) => _ReportBody(report: r),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final MemberReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final fmt = DateFormat.MMMd();

    String weightLine() {
      if (r.latestKg == null) return 'No weight logged';
      final change = r.changeKg;
      if (change == null || change == 0) {
        return '${r.latestKg!.toStringAsFixed(1)} kg';
      }
      final sign = change > 0 ? '+' : '';
      return '${r.latestKg!.toStringAsFixed(1)} kg ($sign${change.toStringAsFixed(1)})';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (r.frozen)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PastelCard(
              tint: PastelTint.butter,
              radius: 20,
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.snowflake, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.status == 'left'
                          ? 'This member left the community. Showing data up to ${fmt.format(r.to)}.'
                          : 'Tracking is on hold. Showing data up to ${fmt.format(r.to)}.',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Report for ${fmt.format(r.from)} – ${fmt.format(r.to)}',
            style: AppTextStyles.caption,
          ),
        ),

        // ── Hero value card (reference screen F) ───────────────────────────
        PastelCard(
          tint: PastelTint.sky,
          radius: 28,
          padding: const EdgeInsets.all(18),
          semanticLabel:
              '${r.workoutCount} workouts, ${r.workoutMinutes} minutes',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsRegular.barbell, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('Workouts', style: AppTextStyles.heading),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${r.workoutCount}', style: AppTextStyles.metricXL),
                    const SizedBox(width: 8),
                    Text('sessions · ${r.workoutMinutes} min',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.ink)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Streak (lime) + nutrition tiles ────────────────────────────────
        PastelCard(
          tint: PastelTint.lime,
          radius: 28,
          padding: const EdgeInsets.all(18),
          semanticLabel: 'Streak ${r.streakDays} days',
          child: ExcludeSemantics(
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.flame, size: 28),
                const SizedBox(width: 12),
                Text('${r.streakDays}', style: AppTextStyles.metricL),
                const SizedBox(width: 8),
                Text('day streak', style: AppTextStyles.body),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: PhosphorIconsRegular.forkKnife,
                label: 'Avg calories',
                value: r.avgCalories?.toString() ?? '—',
                unit: 'kcal',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: PhosphorIconsRegular.egg,
                label: 'Avg protein',
                value: r.avgProteinG?.toString() ?? '—',
                unit: 'g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: PhosphorIconsRegular.calendarCheck,
                label: 'Days logged food',
                value: '${r.loggedDays}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                icon: PhosphorIconsRegular.scales,
                label: 'Weight',
                value: weightLine(),
              ),
            ),
          ],
        ),

        // ── Challenges ─────────────────────────────────────────────────────
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Challenges', style: AppTextStyles.heading),
        ),
        if (r.challenges.isEmpty)
          Text('No challenges yet.', style: AppTextStyles.caption)
        else
          for (final c in r.challenges)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PastelCard(
                radius: 24,
                semanticLabel:
                    '${c.title}, ${c.completedDays} of ${c.totalDays} days',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(c.title, style: AppTextStyles.heading)),
                          Text('${c.completedDays}/${c.totalDays}',
                              style: AppTextStyles.bodyStrong),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: c.totalDays == 0
                              ? 0
                              : c.completedDays / c.totalDays,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceMuted,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
