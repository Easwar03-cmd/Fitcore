import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_models.dart';
import '../../../core/theme/app_colors.dart';

/// One chat message in a WhatsApp-style bubble. Pure widget — all actions come
/// in as callbacks.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onLongPress,
    this.onOpenChallenge,
  });

  final CommunityMessage message;
  final bool isMine;
  final VoidCallback onLongPress;
  final void Function(String challengeId)? onOpenChallenge;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.kind == 'challenge_event' && !m.deleted) return _eventPill(context);
    if (m.kind == 'update' && !m.deleted) return _updateCard(context);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = m.deleted
        ? AppColors.surfaceMuted
        : isMine
            ? AppColors.sky
            : Colors.white;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: m.deleted ? null : onLongPress,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMine ? 14 : 3),
              bottomRight: Radius.circular(isMine ? 3 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine && !m.deleted)
                Text(
                  m.author.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (m.replyTo != null) _replyQuote(context),
              if (m.deleted)
                Text(
                  'This message was deleted',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                )
              else ...[
                if (m.kind == 'notepad_share') _notepadHeader(context),
                if (m.mediaType != null) _media(context),
                if (m.body != null && m.body!.isNotEmpty)
                  Text(m.body!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  DateFormat.jm().format(m.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyQuote(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.5),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.authorName,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
          Text(r.body ?? 'Message deleted',
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _notepadHeader(BuildContext context) {
    final p = message.payload;
    final title = p?['title'] as String? ?? 'Challenge';
    final done = (p?['completedDays'] as num?)?.toInt();
    final total = (p?['totalDays'] as num?)?.toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sticky_note_2_outlined, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              done != null && total != null ? '$title · $done/$total days' : title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _media(BuildContext context) {
    final m = message;
    final url = m.mediaUrl;
    if (m.mediaType == 'image' && url != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 80,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      );
    }
    final icon = m.mediaType == 'video'
        ? Icons.play_circle_outline_rounded
        : Icons.insert_drive_file_outlined;
    return InkWell(
      onTap: url == null
          ? null
          : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(m.mediaName ?? (m.mediaType == 'video' ? 'Video' : 'File'),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final challengeId = message.payload?['challengeId'] as String?;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ActionChip(
          avatar: const Icon(Icons.emoji_events_outlined, size: 18),
          backgroundColor: cs.secondaryContainer,
          label: Text('${message.author.name} ${message.body ?? ''}'),
          onPressed: challengeId == null || onOpenChallenge == null
              ? null
              : () => onOpenChallenge!(challengeId),
        ),
      ),
    );
  }

  Widget _updateCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded, size: 18, color: cs.tertiary),
                const SizedBox(width: 6),
                Text('Update from ${message.author.name}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(message.body ?? '', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(DateFormat.MMMd().add_jm().format(message.createdAt),
                  style: theme.textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Today" / "Yesterday" / "Mar 3" separator between days.
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : DateFormat.yMMMd().format(date);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}
