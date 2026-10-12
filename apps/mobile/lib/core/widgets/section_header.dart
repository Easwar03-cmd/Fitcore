import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Muted section label with optional trailing action ("Select exercise type").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.caption.copyWith(fontSize: 13),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Text(actionLabel!,
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: AppColors.teal, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Large left-aligned screen headline (reference "Tracking your heart").
class DisplayHeadline extends StatelessWidget {
  const DisplayHeadline(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTextStyles.display),
      ),
    );
  }
}
