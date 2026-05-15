import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../providers/coach_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/coach_input_bar.dart';

// ── Chat item types ───────────────────────────────────────────────────────────

sealed class _ChatItem {}

class _MessageItem extends _ChatItem {
  _MessageItem(this.message);
  final ChatMessage message;
}

class _DateLabel extends _ChatItem {
  _DateLabel(this.date);
  final DateTime date;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('Your conversation history will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(coachNotifierProvider.notifier).clearHistory();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _isLoading = true);

    try {
      await ref.read(coachNotifierProvider.notifier).sendMessage(text);
    } catch (e) {
      if (mounted) {
        final msg = e is CoachUnavailableException
            ? e.message
            : 'Something went wrong. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _controller.text = text;
                _send();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChatMessage> _expandForDisplay(List<ChatMessage> messages) {
    final result = <ChatMessage>[];
    for (final msg in messages) {
      if (msg.role == MessageRole.coach) {
        final parts = msg.text
            .split('\n\n')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length > 1) {
          for (var i = 0; i < parts.length; i++) {
            result.add(ChatMessage(
              id: '${msg.id}_$i',
              role: MessageRole.coach,
              text: parts[i],
              timestamp: msg.timestamp,
            ));
          }
          continue;
        }
      }
      result.add(msg);
    }
    return result;
  }

  List<_ChatItem> _buildItems(List<ChatMessage> messages) {
    final items = <_ChatItem>[];
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final isNewDay = i == 0 ||
          !_isSameDay(messages[i - 1].timestamp, msg.timestamp);
      if (isNewDay) items.add(_DateLabel(msg.timestamp));
      items.add(_MessageItem(msg));
    }
    return items;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(coachNotifierProvider);
    final display = _buildItems(_expandForDisplay(messages));
    final hasRealHistory = messages.any((m) => !m.isLocal);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Revive Coach'),
          ],
        ),
        actions: [
          if (hasRealHistory)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear chat',
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: display.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: TypingIndicator(),
                  );
                }
                final itemIndex =
                    display.length - 1 - (index - (_isLoading ? 1 : 0));
                final item = display[itemIndex];
                return switch (item) {
                  _MessageItem(:final message) => ChatBubble(message: message),
                  _DateLabel(:final date) => _DateSeparator(date: date),
                };
              },
            ),
          ),
          CoachInputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: _isLoading,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Date separator widget ─────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
