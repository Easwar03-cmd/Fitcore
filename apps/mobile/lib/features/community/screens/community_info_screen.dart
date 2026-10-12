import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/community_models.dart';
import '../providers/community_provider.dart';

class CommunityInfoScreen extends ConsumerWidget {
  const CommunityInfoScreen({super.key, required this.communityId});
  final String communityId;

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _toggleConsent(
      BuildContext context, WidgetRef ref, bool share) async {
    if (share) {
      final ok = await _confirm(
        context,
        title: 'Share your report?',
        body: 'The admin will be able to see your workouts, calorie and weight '
            'summary, streak and your challenge progress in this community, '
            'starting today. You can stop sharing at any time — it takes '
            'effect immediately.',
        action: 'Share',
      );
      if (!ok || !context.mounted) return;
    }
    try {
      await ref.read(communityActionsProvider).setConsent(communityId, share: share);
    } on CommunityException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Leave community?',
      body: 'The admin stops tracking you immediately. Your own app data is '
          'not affected.',
      action: 'Leave',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(communityActionsProvider).leave(communityId);
      if (context.mounted) context.go(AppRoutes.community);
    } on CommunityException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detail = ref.watch(communityDetailProvider(communityId));
    final members = ref.watch(communityMembersProvider(communityId));
    final myId = ref.watch(authProvider).valueOrNull?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Community info')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (c) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('${c.memberCount} members'),
                  if (c.description != null) ...[
                    const SizedBox(height: 8),
                    Text(c.description!),
                  ],
                ],
              ),
            ),
            if (c.inviteCode != null)
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Invite code'),
                subtitle: Text(c.inviteCode!,
                    style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.inviteCode!));
                        _toast(context, 'Code copied');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => Share.share(
                        'Join "${c.name}" on Revive — open Community → Search '
                        'and enter code ${c.inviteCode}',
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Challenges'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  context.push(AppRoutes.communityChallengesPath(communityId)),
            ),
            if (c.isAdmin)
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Admin settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    context.push(AppRoutes.communityAdminPath(communityId)),
              )
            else ...[
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Share my fitness report with admin'),
                subtitle: Text(c.shareReport
                    ? 'The admin can see your report and challenge progress.'
                    : 'Off — the admin cannot see your data.'),
                value: c.shareReport,
                onChanged: (v) => _toggleConsent(context, ref, v),
              ),
            ],
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Members', style: theme.textTheme.titleSmall),
            ),
            members.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(e.toString()),
              ),
              data: (list) => Column(
                children: [
                  for (final m in list)
                    _MemberRow(
                      member: m,
                      isMe: m.userId == myId,
                      viewerIsAdmin: c.isAdmin,
                      onTap: c.isAdmin && m.role != 'admin' && m.status != 'pending'
                          ? () => context.push(
                              AppRoutes.communityMemberPath(communityId, m.userId))
                          : null,
                      onApprove: c.isAdmin && m.status == 'pending'
                          ? () => ref
                              .read(communityActionsProvider)
                              .memberAction(communityId, m.userId, 'approve')
                          : null,
                    ),
                ],
              ),
            ),
            const Divider(),
            if (!c.isAdmin)
              ListTile(
                leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text('Leave community',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () => _leave(context, ref),
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report community'),
              onTap: () async {
                try {
                  await ref
                      .read(communityActionsProvider)
                      .report(communityId: communityId, reason: 'other');
                  if (context.mounted) {
                    _toast(context, 'Thanks — we will review this community.');
                  }
                } on CommunityException catch (e) {
                  if (context.mounted) _toast(context, e.message);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.viewerIsAdmin,
    this.onTap,
    this.onApprove,
  });

  final CommunityMemberInfo member;
  final bool isMe;
  final bool viewerIsAdmin;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final badges = <String>[
      if (m.role == 'admin') 'Admin',
      if (m.status == 'on_hold') 'On hold',
      if (m.status == 'left') 'Left',
      if (m.status == 'pending') 'Requested',
      if (viewerIsAdmin && m.role != 'admin' && m.shareReport == true && m.status != 'left')
        'Sharing',
    ];
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase()),
      ),
      title: Text(isMe ? '${m.name} (you)' : m.name),
      subtitle: badges.isEmpty ? null : Text(badges.join(' · ')),
      trailing: onApprove != null
          ? FilledButton.tonal(onPressed: onApprove, child: const Text('Approve'))
          : onTap != null
              ? const Icon(Icons.chevron_right_rounded)
              : null,
    );
  }
}
