import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/community_provider.dart';
import '../widgets/community_tile.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(communityListProvider);

    return Scaffold(
      appBar: PageAppBar(
        showBack: false,
        title: 'Community',
        actions: [
          CircleIconButton(
            icon: PhosphorIconsRegular.magnifyingGlass,
            semanticLabel: 'Find or join a community',
            onPressed: () => context.push(AppRoutes.communitySearch),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(communityListProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // Create button sits under the header, on the left.
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.communityCreate),
                icon: const Icon(PhosphorIconsBold.plus, size: 18),
                label: const Text('Create community'),
              ),
            ),
            const SizedBox(height: 28),
            HeroCard(
              tint: PastelTint.lime,
              chipLabel: 'Community',
              chipIcon: PhosphorIconsFill.usersThree,
              title: 'Train together',
              subtitle: 'Join by invite or search by name',
              ctaLabel: 'Find communities',
              onCta: () => context.push(AppRoutes.communitySearch),
              imageName: 'hero_community.jpg',
              fallbackIcon: PhosphorIconsRegular.usersThree,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('Joined communities',
                  style: AppTextStyles.caption.copyWith(fontSize: 13)),
            ),
            communities.when(
              loading: () => const Column(
                children: [
                  Skeleton(height: 72, radius: 24),
                  SizedBox(height: 10),
                  Skeleton(height: 72, radius: 24),
                ],
              ),
              error: (e, _) => PastelCard(
                tint: PastelTint.salmon,
                radius: 24,
                child: Row(
                  children: [
                    Expanded(child: Text(e.toString())),
                    TextButton(
                      onPressed: () =>
                          ref.read(communityListProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Not joined community yet',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.inkMuted.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in list)
                          CommunityTile(
                            community: c,
                            onTap: c.isPending
                                ? () => ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Waiting for the admin to approve your request.'),
                                      ),
                                    )
                                : () => context
                                    .push(AppRoutes.communityChatPath(c.id)),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            PastelCard(
              tint: PastelTint.sky,
              radius: 24,
              onTap: () => context.push(AppRoutes.communityChallenges),
              semanticLabel: 'Challenges across your communities',
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsRegular.trophy, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Challenges', style: AppTextStyles.heading),
                        Text('Personal and group, across your communities',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.ink)),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsRegular.caretRight, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PastelCard(
              tint: PastelTint.butter,
              radius: 24,
              onTap: () => context.push(AppRoutes.communityTodo),
              semanticLabel: 'My daily to-do. Private, only you can see it.',
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsRegular.checkSquareOffset,
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My daily to-do', style: AppTextStyles.heading),
                        Text('Private — only you can see this',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.ink)),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsRegular.caretRight, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
