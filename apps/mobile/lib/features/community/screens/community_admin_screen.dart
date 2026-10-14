import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../providers/community_provider.dart';
import '../../../core/widgets/page_app_bar.dart';

/// Admin-only settings for a community.
class CommunityAdminScreen extends ConsumerStatefulWidget {
  const CommunityAdminScreen({super.key, required this.communityId});
  final String communityId;

  @override
  ConsumerState<CommunityAdminScreen> createState() =>
      _CommunityAdminScreenState();
}

class _CommunityAdminScreenState extends ConsumerState<CommunityAdminScreen> {
  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _patch(Map<String, Object?> patch) async {
    try {
      await ref
          .read(communityActionsProvider)
          .updateSettings(widget.communityId, patch);
    } on CommunityException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _rename(String current, String? description) async {
    final name = TextEditingController(text: current);
    final desc = TextEditingController(text: description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: desc,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await _patch({
        'name': name.text.trim(),
        'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
      });
    }
    name.dispose();
    desc.dispose();
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New invite code?'),
        content: const Text('The old code will stop working immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final code = await ref
          .read(communityActionsProvider)
          .regenerateInvite(widget.communityId);
      _toast('New code: $code');
    } on CommunityException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete community?'),
        content: const Text(
            'All messages, challenges and member tracking in this community '
            'will be permanently deleted for everyone. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(communityActionsProvider)
          .deleteCommunity(widget.communityId);
      if (mounted) context.go(AppRoutes.community);
    } on CommunityException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(communityDetailProvider(widget.communityId));
    return Scaffold(
      appBar: const PageAppBar(title: 'Admin settings'),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            PastelCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Name & description'),
              subtitle: Text(c.name),
              onTap: () => _rename(c.name, c.description),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.public_rounded),
              title: const Text('Discoverable in search'),
              subtitle: const Text('Off = invite-only'),
              value: c.isPublic,
              onChanged: (v) => _patch({'isPublic': v}),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.how_to_reg_outlined),
              title: const Text('Approve new members'),
              subtitle: const Text('People must be accepted before joining'),
              value: c.requireApproval,
              onChanged: (v) => _patch({'requireApproval': v}),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Members can send messages'),
              subtitle: const Text('Off = only you can post'),
              value: c.membersCanChat,
              onChanged: (v) => _patch({'membersCanChat': v}),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.person_add_alt_outlined),
              title: const Text('Members can share the invite code'),
              value: c.membersCanInvite,
              onChanged: (v) => _patch({'membersCanInvite': v}),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Generate new invite code'),
              subtitle: Text(c.inviteCode ?? ''),
              onTap: _regenerate,
            ),
              ]),
            ),
            const SizedBox(height: 12),
            PastelCard(
              tint: PastelTint.salmon,
              radius: 24,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: const Icon(PhosphorIconsRegular.trash),
                title: Text('Delete community', style: AppTextStyles.heading),
                onTap: _delete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
