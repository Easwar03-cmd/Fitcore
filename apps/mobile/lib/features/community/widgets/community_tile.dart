import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';
import '../models/community_models.dart';

const _tints = [
  PastelTint.sky,
  PastelTint.lime,
  PastelTint.butter,
  PastelTint.salmon,
];

class CommunityTile extends StatelessWidget {
  const CommunityTile({super.key, required this.community, required this.onTap});

  final CommunitySummary community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = community;
    final tint = _tints[c.name.hashCode.abs() % _tints.length];
    final subtitle = c.isPending
        ? 'Waiting for approval'
        : (c.lastMessagePreview ?? '${c.memberCount} members');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PastelCard(
        radius: 24,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        semanticLabel:
            '${c.name}. $subtitle.${c.isAdmin ? ' You are the admin.' : ''}',
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: tint.color, shape: BoxShape.circle),
              child: Text(
                c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                style: AppTextStyles.heading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading),
                      ),
                      if (c.isAdmin) ...[
                        const SizedBox(width: 8),
                        const PastelChip(label: 'Admin', filled: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 18),
          ],
        ),
      ),
    );
  }
}
