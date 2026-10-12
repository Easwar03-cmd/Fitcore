import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_response.dart' show apiErrorMessage;

/// Flag button for AI-generated content (Google Play generative-AI policy).
/// Sends the report to `POST /ai/report`, which logs it for review.
class ReportAiButton extends ConsumerWidget {
  const ReportAiButton({
    super.key,
    required this.contentLabel,
    this.size = 20,
  });

  /// Short description of what is being reported, e.g. "AI meal plan".
  final String contentLabel;
  final double size;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report this AI result'),
        children: [
          for (final r in const [
            ('harmful', 'Harmful or unsafe'),
            ('inaccurate', 'Inaccurate'),
            ('offensive', 'Offensive'),
            ('other', 'Something else'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r.$1),
              child: Text(r.$2),
            ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).dio.post('/ai/report', data: {
        'messageText': contentLabel,
        'reason': reason,
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks — we will review this.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Report this result',
      icon: Icon(Icons.flag_outlined, size: size),
      onPressed: () => _report(context, ref),
    );
  }
}
