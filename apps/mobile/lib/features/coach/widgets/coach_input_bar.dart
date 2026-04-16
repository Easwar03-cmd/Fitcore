import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CoachInputBar extends StatelessWidget {
  const CoachInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.isRateLimited,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final bool isRateLimited;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isRateLimited,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.onBackground),
                decoration: InputDecoration(
                  hintText: isRateLimited
                      ? 'Upgrade to Pro for more messages'
                      : 'Ask your coach...',
                  hintStyle: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isLoading || isRateLimited ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: isLoading || isRateLimited
                    ? AppColors.surfaceVariant
                    : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
