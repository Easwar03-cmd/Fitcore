import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../providers/community_provider.dart';
import '../widgets/community_tile.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final communities = ref.watch(communityListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            tooltip: 'Find or join a community',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppRoutes.communitySearch),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(communityListProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Create button sits under the header, on the left.
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.communityCreate),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create community'),
              ),
            ),
            const SizedBox(height: 20),
            Text('Joined communities', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            communities.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorRow(
                message: e.toString(),
                onRetry: () => ref.read(communityListProvider.notifier).refresh(),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Not joined community yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in list)
                          CommunityTile(
                            community: c,
                            onTap: c.isPending
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Waiting for the admin to approve your request.'),
                                      ),
                                    )
                                : () => context.push(AppRoutes.communityChatPath(c.id)),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            _TodoEntry(onTap: () => context.push(AppRoutes.communityTodo)),
          ],
        ),
      ),
    );
  }
}

class _TodoEntry extends StatelessWidget {
  const _TodoEntry({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.checklist_rounded, color: theme.colorScheme.primary),
        ),
        title: const Text('My daily to-do'),
        subtitle: const Text('Private — only you can see this'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
