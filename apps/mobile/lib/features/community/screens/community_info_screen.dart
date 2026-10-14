import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';
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
    final detail = ref.watch(communityDetailProvider(communityId));
    final members = ref.watch(communityMembersProvider(communityId));
    final myId = ref.watch(authProvider).valueOrNull?.user.id;

    return Scaffold(
      appBar: const PageAppBar(title: 'Community info'),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // ── Title block ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(c.name, style: AppTextStyles.title),
                  ),
                  const SizedBox(height: 4),
                  Text('${c.memberCount} members',
                      style: AppTextStyles.caption),
                  if (c.description != null) ...[
                    const SizedBox(height: 8),
                    Text(c.description!, style: AppTextStyles.body),
                  ],
                ],
              ),
            ),

            // ── Invite code ────────────────────────────────────────────────
            if (c.inviteCode != null) ...[
              PastelCard(
                tint: PastelTint.butter,
                radius: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite code',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text(
                            c.inviteCode!,
                            style: AppTextStyles.metricM
                                .copyWith(letterSpacing: 3),
                          ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: PhosphorIconsRegular.copy,
                      semanticLabel: 'Copy invite code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.inviteCode!));
                        _toast(context, 'Code copied');
                      },
                    ),
                    const SizedBox(width: 6),
                    CircleIconButton(
                      icon: PhosphorIconsRegular.shareNetwork,
                      semanticLabel: 'Share invite',
                      onPressed: () => Share.share(
                        'Join "${c.name}" on Revive — open Community → Search '
                        'and enter code ${c.inviteCode}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Navigation rows ────────────────────────────────────────────
            if (c.isAdmin) ...[
              _NavRow(
                icon: PhosphorIconsRegular.gearSix,
                tint: PastelTint.lime,
                title: 'Admin settings',
                onTap: () =>
                    context.push(AppRoutes.communityAdminPath(communityId)),
              ),
            ] else ...[
              const SizedBox(height: 12),
              PastelCard(
                tint: c.shareReport ? PastelTint.lime : PastelTint.white,
                radius: 24,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsRegular.heartbeat),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Share my fitness report',
                              style: AppTextStyles.heading),
                          Text(
                            c.shareReport
                                ? 'The admin can see your report and challenges.'
                                : 'Off — the admin cannot see your data.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: c.shareReport,
                      onChanged: (v) => _toggleConsent(context, ref, v),
                    ),
                  ],
                ),
              ),
            ],

            // ── Members ────────────────────────────────────────────────────
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Members', style: AppTextStyles.heading),
            ),
            members.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(e.toString()),
              data: (list) => PastelCard(
                radius: 24,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      _MemberRow(
                        member: list[i],
                        isMe: list[i].userId == myId,
                        viewerIsAdmin: c.isAdmin,
                        onTap: c.isAdmin &&
                                list[i].role != 'admin' &&
                                list[i].status != 'pending'
                            ? () => context.push(AppRoutes.communityMemberPath(
                                communityId, list[i].userId))
                            : null,
                        onApprove: c.isAdmin && list[i].status == 'pending'
                            ? () => ref.read(communityActionsProvider).memberAction(
                                communityId, list[i].userId, 'approve')
                            : null,
                      ),
                      if (i < list.length - 1)
                        const Divider(indent: 70, endIndent: 16),
                    ],
                  ],
                ),
              ),
            ),

            // ── Leave / report ─────────────────────────────────────────────
            const SizedBox(height: 20),
            if (!c.isAdmin)
              _NavRow(
                icon: PhosphorIconsRegular.signOut,
                tint: PastelTint.salmon,
                title: 'Leave community',
                onTap: () => _leave(context, ref),
              ),
            if (!c.isAdmin) const SizedBox(height: 10),
            _NavRow(
              icon: PhosphorIconsRegular.flag,
              tint: PastelTint.grey,
              title: 'Report community',
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

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final PastelTint tint;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      radius: 24,
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: tint.color, shape: BoxShape.circle),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: AppTextStyles.heading)),
          const Icon(PhosphorIconsRegular.caretRight, size: 18),
        ],
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
      if (viewerIsAdmin &&
          m.role != 'admin' &&
          m.shareReport == true &&
          m.status != 'left')
        'Sharing',
    ];
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.sky,
                child: Text(
                  m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                  style: AppTextStyles.heading.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMe ? '${m.name} (you)' : m.name,
                        style: AppTextStyles.bodyStrong),
                    if (badges.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final b in badges)
                              PastelChip(
                                label: b,
                                background: b == 'Sharing'
                                    ? AppColors.lime
                                    : AppColors.surfaceMuted,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (onApprove != null)
                FilledButton.tonal(
                    onPressed: onApprove, child: const Text('Approve'))
              else if (onTap != null)
                const Icon(PhosphorIconsRegular.caretRight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
