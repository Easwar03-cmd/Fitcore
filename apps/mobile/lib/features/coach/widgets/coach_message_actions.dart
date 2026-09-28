import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reasons a user can give when reporting an AI response. Keys match the
/// backend's `/ai/report` schema.
const _kReportReasons = <String, String>{
  'harmful': 'Harmful or unsafe advice',
  'inaccurate': 'Inaccurate information',
  'offensive': 'Offensive or inappropriate',
  'other': 'Something else',
};

/// Long-press menu for a coach message: copy, or report it.
/// Returns the chosen report reason key, or null if the user didn't report.
Future<String?> showCoachMessageActions(
  BuildContext context,
  String messageText,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: _ActionsBody(messageText: messageText),
    ),
  );
}

class _ActionsBody extends StatefulWidget {
  const _ActionsBody({required this.messageText});
  final String messageText;

  @override
  State<_ActionsBody> createState() => _ActionsBodyState();
}

class _ActionsBodyState extends State<_ActionsBody> {
  bool _choosingReason = false;

  @override
  Widget build(BuildContext context) {
    if (!_choosingReason) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.messageText));
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report response'),
            onTap: () => setState(() => _choosingReason = true),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Why are you reporting this response?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final entry in _kReportReasons.entries)
          ListTile(
            title: Text(entry.value),
            onTap: () => Navigator.pop(context, entry.key),
          ),
      ],
    );
  }
}

/// Persistent notice shown above the coach input bar.
class CoachDisclaimer extends StatelessWidget {
  const CoachDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        'AI responses can be wrong and are not medical advice. '
        'Consult a doctor about health concerns. Long-press a reply to report it.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
