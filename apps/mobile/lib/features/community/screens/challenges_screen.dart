import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../models/community_models.dart';
import '../providers/challenge_provider.dart';
import '../providers/community_provider.dart' show communityListProvider;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/widgets/page_app_bar.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(allChallengesProvider);

    return Scaffold(
      appBar: const PageAppBar(title: 'Challenges'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.communityNewChallenge);
          ref.invalidate(allChallengesProvider);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New challenge'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communityListProvider);
          ref.invalidate(allChallengesProvider);
          await ref.read(allChallengesProvider.future);
        },
        child: challenges.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(padding: const EdgeInsets.all(24), child: Text(e.toString())),
          ]),
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _ChallengeHero(),
              const SizedBox(height: 16),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No challenges yet.\nStart a 21-day or 90-day challenge '
                    'and mark each day complete.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              for (final item in list)
                _ChallengeCard(
                  challenge: item.challenge,
                  communityName: item.community.name,
                  onTap: () async {
                    await context.push(AppRoutes.communityChallengePath(
                        item.community.id, item.challenge.id));
                    ref.invalidate(allChallengesProvider);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const HeroCard(
      tint: PastelTint.butter,
      chipLabel: 'Challenges',
      chipIcon: PhosphorIconsFill.trophy,
      title: 'Show up every day',
      subtitle: 'Mark each day complete',
      imageName: 'challenge_medal.png',
      fallbackIcon: PhosphorIconsRegular.medal,
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.communityName,
    required this.onTap,
  });
  final ChallengeSummary challenge;
  final String communityName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = challenge;
    final mine = c.mine;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.title, style: theme.textTheme.titleMedium),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(c.isGroup ? 'Group' : 'Personal'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$communityName · ${c.totalDays} days · by ${c.creatorName}'
                '${c.isGroup ? ' · ${c.participantCount} joined' : ''}'
                '${c.status == 'closed' ? ' · closed' : ''}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (mine != null) ...[
                LinearProgressIndicator(value: mine.fraction),
                const SizedBox(height: 4),
                Text(
                  mine.status == 'completed'
                      ? 'Completed 🎉'
                      : '${mine.completedDays} / ${mine.totalDays} days done',
                  style: theme.textTheme.bodySmall,
                ),
              ] else
                Text('Tap to view and join',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
