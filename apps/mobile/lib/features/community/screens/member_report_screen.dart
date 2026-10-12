import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/community_models.dart';
import '../providers/community_provider.dart';

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
      appBar: AppBar(
        title: Text(member?.name ?? 'Member'),
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
    final theme = Theme.of(context);
    final r = report;
    final fmt = DateFormat.MMMd();

    Widget stat(String label, String value, IconData icon) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(value, style: theme.textTheme.titleMedium),
                  Text(label,
                      style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );

    String weightLine() {
      if (r.latestKg == null) return 'No weight logged';
      final change = r.changeKg;
      if (change == null || change == 0) return '${r.latestKg!.toStringAsFixed(1)} kg';
      final sign = change > 0 ? '+' : '';
      return '${r.latestKg!.toStringAsFixed(1)} kg ($sign${change.toStringAsFixed(1)})';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (r.frozen)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              r.status == 'left'
                  ? 'This member left the community. Showing data up to ${fmt.format(r.to)}.'
                  : 'Tracking is on hold. Showing data up to ${fmt.format(r.to)}.',
            ),
          ),
        Text(
          'Report for ${fmt.format(r.from)} – ${fmt.format(r.to)}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            stat('Workouts', '${r.workoutCount}', Icons.fitness_center_rounded),
            stat('Minutes', '${r.workoutMinutes}', Icons.timer_outlined),
            stat('Streak', '${r.streakDays}d', Icons.local_fire_department_outlined),
          ],
        ),
        Row(
          children: [
            stat('Days logged food', '${r.loggedDays}', Icons.restaurant_outlined),
            stat('Avg kcal', r.avgCalories?.toString() ?? '—',
                Icons.local_fire_department_rounded),
            stat('Avg protein', r.avgProteinG == null ? '—' : '${r.avgProteinG} g',
                Icons.egg_alt_outlined),
          ],
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Weight'),
            subtitle: Text(weightLine()),
          ),
        ),
        const SizedBox(height: 12),
        Text('Challenges', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (r.challenges.isEmpty)
          const Text('No challenges yet.')
        else
          for (final c in r.challenges)
            Card(
              child: ListTile(
                title: Text(c.title),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(
                    value: c.totalDays == 0 ? 0 : c.completedDays / c.totalDays,
                  ),
                ),
                trailing: Text('${c.completedDays}/${c.totalDays}'),
              ),
            ),
      ],
    );
  }
}
