import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/coach_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/coach_input_bar.dart';

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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _isLoading = true);

    try {
      await ref.read(coachNotifierProvider.notifier).sendMessage(text);
    } on RateLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily message limit reached (5/5). Upgrade to Pro for unlimited coaching.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get response. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(coachNotifierProvider);
    final rateLimit = ref.watch(coachRateLimitProvider);
    final isRateLimited =
        rateLimit.limit > 0 && rateLimit.used >= rateLimit.limit;

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
            const Text('Zenfit Coach'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (rateLimit.limit > 0 && rateLimit.used > 0)
            _RateLimitBanner(used: rateLimit.used, limit: rateLimit.limit),
          Expanded(
            child: messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: TypingIndicator(),
                        );
                      }
                      final msgIndex = messages.length -
                          1 -
                          (index - (_isLoading ? 1 : 0));
                      return ChatBubble(message: messages[msgIndex]);
                    },
                  ),
          ),
          CoachInputBar(
            controller: _controller,
            focusNode: _focusNode,
            isLoading: _isLoading,
            isRateLimited: isRateLimited,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ─── Rate-limit banner ────────────────────────────────────────────────────────

class _RateLimitBanner extends StatelessWidget {
  const _RateLimitBanner({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade100,
      child: Text(
        '$used / $limit messages used today',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.amber.shade900,
            ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your AI Coach',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.onBackground),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me anything about your workouts, nutrition, or fitness goals.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            ..._suggestions.map((s) => _SuggestionChip(text: s)),
          ],
        ),
      ),
    );
  }
}

const _suggestions = [
  'How many calories should I eat today?',
  'Give me a quick 20-minute workout',
  'Am I overtraining this week?',
];

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () =>
            ref.read(coachNotifierProvider.notifier).sendMessage(text),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurface),
          ),
        ),
      ),
    );
  }
}
