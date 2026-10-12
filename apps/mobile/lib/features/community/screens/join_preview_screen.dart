import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../providers/community_provider.dart';
import '../../../core/widgets/page_app_bar.dart';

/// Landing screen for an invite code (typed in, or opened from a shared link).
class JoinPreviewScreen extends ConsumerStatefulWidget {
  const JoinPreviewScreen({super.key, required this.code});
  final String code;

  @override
  ConsumerState<JoinPreviewScreen> createState() => _JoinPreviewScreenState();
}

class _JoinPreviewScreenState extends ConsumerState<JoinPreviewScreen> {
  bool _joining = false;

  Future<void> _join(String communityId) async {
    setState(() => _joining = true);
    try {
      final status = await ref
          .read(communityListProvider.notifier)
          .join(code: widget.code);
      if (!mounted) return;
      if (status == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request sent. The admin needs to approve it.'),
        ));
        context.go(AppRoutes.community);
      } else {
        context.go(AppRoutes.communityChatPath(communityId));
      }
    } on CommunityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(invitePreviewProvider(widget.code));
    return Scaffold(
      appBar: const PageAppBar(title: 'Join community'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: preview.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (c) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 16),
              Text(c.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${c.memberCount} members'),
              if (c.description != null) ...[
                const SizedBox(height: 12),
                Text(c.description!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _joining ? null : () => _join(c.id),
                child: Text(c.requireApproval ? 'Request to join' : 'Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
