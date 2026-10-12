import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'circle_icon_button.dart';

/// Detail-screen header: circle back · centred small title · circle actions
/// (reference screens B / C). Use [PageAppBar.plain] for the chevron variant
/// (reference screen F).
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    this.title,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.plain = false,
    this.backgroundColor,
  });

  const PageAppBar.plain({
    super.key,
    this.title,
    this.actions = const [],
    this.onBack,
  })  : showBack = true,
        plain = true,
        backgroundColor = null;

  final String? title;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final bool plain;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    void back() => onBack != null ? onBack!() : context.pop();

    final leading = !showBack || !canPop && onBack == null
        ? const SizedBox(width: 44)
        : plain
            ? IconButton(
                tooltip: 'Back',
                onPressed: back,
                icon: const Icon(PhosphorIconsRegular.caretLeft, size: 24),
              )
            : CircleIconButton(
                icon: PhosphorIconsRegular.arrowLeft,
                semanticLabel: 'Back',
                onPressed: back,
              );

    return Material(
      color: backgroundColor ?? AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                leading,
                Expanded(
                  child: Center(
                    child: title == null
                        ? null
                        : Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headerTitle,
                          ),
                  ),
                ),
                if (actions.isEmpty)
                  const SizedBox(width: 44)
                else
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home-style header: avatar + greeting + circle bell (reference screens A / D / E).
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    this.greeting = 'Hello',
    this.onAvatarTap,
    this.trailing,
  });

  final String name;
  final String greeting;
  final VoidCallback? onAvatarTap;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open profile',
            child: GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.sky,
                child: Text(initial,
                    style: AppTextStyles.heading.copyWith(fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$greeting, $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong,
            ),
          ),
          ...?trailing,
        ],
      ),
    );
  }
}
