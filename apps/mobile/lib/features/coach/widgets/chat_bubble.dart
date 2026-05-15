import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.timestamp);
    final timeColor = _isUser
        ? Colors.white.withValues(alpha: 0.65)
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.65);

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;

    final bubble = IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: _isUser
                ? AppColors.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: _isUser
                  ? const Radius.circular(18)
                  : const Radius.circular(4),
              bottomRight: _isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _isUser
                    ? Text(
                        message.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              height: 1.4,
                            ),
                      )
                    : _CoachMessageBody(text: message.text),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: timeColor,
                          height: 1,
                        ),
                  ),
                  if (_isUser) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.done_all_rounded, size: 14, color: timeColor),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final Widget row = _isUser
        ? Align(
            alignment: Alignment.centerRight,
            child: bubble,
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              bubble,
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: row,
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }
}

// ── Coach message body ────────────────────────────────────────────────────────

class _CoachMessageBody extends StatelessWidget {
  const _CoachMessageBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.5,
          ),
    );
  }
}

// ── Typing indicator shown while the assistant is responding ──────────────────

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.psychology_outlined,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                    begin: 0.6,
                    end: 1.0,
                    delay: (i * 200).ms,
                    duration: 400.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .scaleXY(begin: 1.0, end: 0.6, duration: 400.ms);
            }),
          ),
        ),
      ],
    );
  }
}
