import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/community_models.dart';
import '../providers/challenge_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/challenge_day_sheets.dart';
import '../../../core/widgets/page_app_bar.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({
    super.key,
    required this.communityId,
    required this.challengeId,
  });

  final String? communityId;
  final String challengeId;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String? success,
  }) async {
    try {
      await action();
      if (context.mounted && success != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } on CommunityException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(challengeDetailProvider(challengeId));
    final cid = communityId;
    final communityAsync =
        cid == null ? null : ref.watch(communityDetailProvider(cid));
    final myId = ref.watch(authProvider).valueOrNull?.user.id;
    final actions = ref.read(challengeActionsProvider);

    return Scaffold(
      appBar: PageAppBar(
        title: detail.valueOrNull?.title ?? 'Challenge',
        actions: [
          if (detail.valueOrNull != null &&
              (detail.value!.creatorId == myId ||
                  (communityAsync?.valueOrNull?.isAdmin ?? false)))
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'close') {
                  await _run(context, () => actions.close(communityId, challengeId),
                      success: 'Challenge closed to new joiners.');
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete challenge?'),
                      content: const Text(
                          'Progress for everyone in this challenge is removed.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await _run(context, () => actions.delete(communityId, challengeId));
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (_) => [
                if (detail.value!.isGroup && detail.value!.status == 'open')
                  const PopupMenuItem(value: 'close', child: Text('Close to new members')),
                const PopupMenuItem(value: 'delete', child: Text('Delete challenge')),
              ],
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (c) => _Body(
          challenge: c,
          communityId: communityId,
          myId: myId,
          onRun: (action, {success}) => _run(context, action, success: success),
        ),
      ),
    );
  }
}

typedef _Runner = Future<void> Function(Future<void> Function() action, {String? success});

class _Body extends ConsumerWidget {
  const _Body({
    required this.challenge,
    required this.communityId,
    required this.myId,
    required this.onRun,
  });

  final ChallengeDetail challenge;
  final String? communityId;
  final String? myId;
  final _Runner onRun;

  /// 1-based day number for today, or null before the start date.
  int? _todayNumber() {
    final start = challenge.startDate;
    if (start == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final n = today.difference(start).inDays + 1;
    return n < 1 ? null : n;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = challenge;
    final actions = ref.read(challengeActionsProvider);
    final todayNo = _todayNumber();
    final done = c.completedDayNumbers;
    final finished = c.myStatus == 'completed';
    final active = c.myStatus == 'active';
    final todayDone = todayNo != null && done.contains(todayNo);
    final pastEnd = todayNo != null && todayNo > c.totalDays;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        if (c.description.isNotEmpty) ...[
          Text(c.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        if (!c.joined)
          _JoinCard(
            challenge: c,
            onJoin: () => onRun(
              () => actions.join(communityId, c.id),
              success: 'You joined this challenge. Day 1 is today.',
            ),
          )
        else ...[
          Row(
            children: [
              Text('${c.completedDays} / ${c.totalDays} days',
                  style: theme.textTheme.titleLarge),
              const Spacer(),
              if (finished) const Chip(label: Text('Completed 🎉')),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: c.totalDays == 0 ? 0 : c.completedDays / c.totalDays,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          if (active && !pastEnd)
            todayDone
                ? OutlinedButton.icon(
                    onPressed: () => onRun(
                      () => actions.undoDay(communityId, c.id, todayNo),
                    ),
                    icon: const Icon(Icons.undo_rounded),
                    label: Text("Undo today's check-in (day $todayNo)"),
                  )
                : FilledButton.icon(
                    onPressed: todayNo == null
                        ? null
                        : () => onRun(() async {
                              final finishedNow =
                                  await actions.markToday(communityId, c.id);
                              if (finishedNow && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Challenge complete — amazing work! 🎉'),
                                  ),
                                );
                              }
                            }),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(todayNo == null
                        ? 'Starts tomorrow'
                        : 'Mark day $todayNo complete'),
                  ),
          if (active && pastEnd)
            Text(
              'The planned ${c.totalDays} days are over. You finished '
              '${c.completedDays} of ${c.totalDays}.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 20),
          ChallengeDaySheets(
            totalDays: c.totalDays,
            startDate: c.startDate!,
            todayNo: todayNo,
            done: done,
            dayNotes: c.dayNotes,
            onSave: (day, text) => actions.saveDayNote(c.id, day, text),
            onShare: communityId == null
                ? null
                : (day) => onRun(
                      () => actions.shareNotes(c.id, day),
                      success: 'Day $day notes shared in the community chat.',
                    ),
          ),
        ],
        if (c.isGroup) ...[
          const SizedBox(height: 24),
          Text('Participants (${c.participants.length})',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final p in c.participants)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
              ),
              title: Text(p.userId == myId ? '${p.name} (you)' : p.name),
              subtitle: LinearProgressIndicator(
                value: c.totalDays == 0 ? 0 : p.completedDays / c.totalDays,
              ),
              trailing: Text('${p.completedDays}/${c.totalDays}'),
            ),
          if (c.joined && c.myStatus == 'active')
            TextButton(
              onPressed: () => onRun(() => actions.leave(communityId, c.id),
                  success: 'You left this challenge.'),
              child: const Text('Leave challenge'),
            ),
        ],
      ],
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.challenge, required this.onJoin});
  final ChallengeDetail challenge;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final open = challenge.status == 'open';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              open
                  ? '${challenge.totalDays}-day challenge. Joining starts '
                      'your own day 1 today.'
                  : 'This challenge is closed to new members.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: open ? onJoin : null,
              child: const Text('Join challenge'),
            ),
          ],
        ),
      ),
    );
  }
}
