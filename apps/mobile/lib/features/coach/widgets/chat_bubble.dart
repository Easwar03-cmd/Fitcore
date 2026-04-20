import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isUser ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
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

// ── Multi-paragraph coach message renderer ────────────────────────────────────

class _CoachMessageBody extends StatelessWidget {
  const _CoachMessageBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: color,
          height: 1.5,
        );

    // Split on double newlines to get paragraphs; single newlines preserved.
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

    if (paragraphs.length <= 1) {
      // Single paragraph — plain text with newlines preserved.
      return Text(text, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Text(paragraphs[i], style: style),
        ],
      ],
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
