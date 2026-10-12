import 'package:flutter/material.dart';

import '../models/community_models.dart';

class CommunityTile extends StatelessWidget {
  const CommunityTile({super.key, required this.community, required this.onTap});

  final CommunitySummary community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = community;
    final subtitle = c.isPending
        ? 'Waiting for approval'
        : (c.lastMessagePreview ?? '${c.memberCount} members');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (c.isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
