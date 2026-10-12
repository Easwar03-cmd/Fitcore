import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/community_models.dart';
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/widgets/skeleton.dart';

class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({super.key, required this.communityId});
  final String communityId;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  CommunityMessage? _replyTo;
  bool _loadingOlder = false;
  bool _reachedStart = false;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _reachedStart) return;
    _loadingOlder = true;
    try {
      final more =
          await ref.read(chatProvider(widget.communityId).notifier).loadOlder();
      if (!more) _reachedStart = true;
    } catch (_) {
      // Ignore — the user can scroll again to retry.
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _send(String text, bool asUpdate) async {
    try {
      await ref.read(chatProvider(widget.communityId).notifier).sendText(
            text,
            asUpdate: asUpdate,
            replyToId: _replyTo?.id,
          );
      if (mounted) setState(() => _replyTo = null);
    } on CommunityException catch (e) {
      _toast(e.message);
      rethrow;
    }
  }

  Future<void> _sendAttachment(OutgoingAttachment file) async {
    try {
      await ref.read(chatProvider(widget.communityId).notifier).sendAttachment(
            file,
            replyToId: _replyTo?.id,
          );
      if (mounted) setState(() => _replyTo = null);
    } on CommunityException catch (e) {
      _toast(e.message);
    }
  }

  void _showActions(CommunityMessage m, {required bool mine, required bool admin}) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = m);
              },
            ),
            if (m.body != null && m.body!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: m.body!));
                },
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _report(m);
                },
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text('Block ${m.author.name}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _block(m.author);
                },
              ),
            if (mine || admin)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(chatProvider(widget.communityId).notifier)
                        .deleteMessage(m.id);
                  } on CommunityException catch (e) {
                    _toast(e.message);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _report(CommunityMessage m) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report message'),
        children: [
          for (final r in const [
            ('spam', 'Spam'),
            ('harassment', 'Harassment or bullying'),
            ('inappropriate', 'Inappropriate content'),
            ('other', 'Something else'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r.$1),
              child: Text(r.$2),
            ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await ref
          .read(communityActionsProvider)
          .report(messageId: m.id, reason: reason);
      _toast('Thanks — we will review this.');
    } on CommunityException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _block(ChatAuthor author) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${author.name}?'),
        content: const Text('You will no longer see their messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(communityActionsProvider).blockUser(author.id);
      ref.invalidate(chatProvider(widget.communityId));
      _toast('${author.name} blocked.');
    } on CommunityException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.communityId;
    final detail = ref.watch(communityDetailProvider(id));
    final chat = ref.watch(chatProvider(id));
    final myId = ref.watch(authProvider).valueOrNull?.user.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => context.push(AppRoutes.communityInfoPath(id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.valueOrNull?.name ?? 'Community',
                    style: Theme.of(context).textTheme.titleMedium),
                if (detail.valueOrNull != null)
                  Text('${detail.value!.memberCount} members',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Challenges',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push(AppRoutes.communityChallengesPath(id)),
          ),
          IconButton(
            tooltip: 'Community info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => context.push(AppRoutes.communityInfoPath(id)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.toString()),
                    TextButton(
                      onPressed: () => ref.invalidate(chatProvider(id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (messages) => _MessageList(
                messages: messages,
                myId: myId,
                isAdmin: detail.valueOrNull?.isAdmin ?? false,
                onReachedTop: _loadOlder,
                onActions: _showActions,
                onOpenChallenge: (cid) =>
                    context.push(AppRoutes.communityChallengePath(id, cid)),
              ),
            ),
          ),
          if (detail.valueOrNull != null && !detail.value!.canPost)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Text(
                  'Only the admin can post in this community.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ChatComposer(
              isAdmin: detail.valueOrNull?.isAdmin ?? false,
              onSendText: _send,
              onSendAttachment: _sendAttachment,
              onError: _toast,
              replyingToLabel: _replyTo == null
                  ? null
                  : 'Replying to ${_replyTo!.author.name}',
              onCancelReply: () => setState(() => _replyTo = null),
            ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.myId,
    required this.isAdmin,
    required this.onReachedTop,
    required this.onActions,
    required this.onOpenChallenge,
  });

  final List<CommunityMessage> messages;
  final String? myId;
  final bool isAdmin;
  final VoidCallback onReachedTop;
  final void Function(CommunityMessage m, {required bool mine, required bool admin})
      onActions;
  final void Function(String challengeId) onOpenChallenge;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const EmptyState(
        icon: PhosphorIconsRegular.chatCircleDots,
        imageName: 'obj_chat.png',
        title: 'No messages yet',
        message: 'Say hello!',
      );
    }

    final reversed = messages.reversed.toList();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) onReachedTop();
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: reversed.length,
        itemBuilder: (context, i) {
          final m = reversed[i];
          // In a reversed list the "previous" (older) message is at i + 1.
          final older = i + 1 < reversed.length ? reversed[i + 1] : null;
          final newDay = older == null ||
              older.createdAt.year != m.createdAt.year ||
              older.createdAt.month != m.createdAt.month ||
              older.createdAt.day != m.createdAt.day;
          final mine = m.author.id == myId;
          return Column(
            children: [
              if (newDay) DateSeparator(date: m.createdAt),
              MessageBubble(
                message: m,
                isMine: mine,
                onLongPress: () => onActions(m, mine: mine, admin: isAdmin),
                onOpenChallenge: onOpenChallenge,
              ),
            ],
          );
        },
      ),
    );
  }
}
