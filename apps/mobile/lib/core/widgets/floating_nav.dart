import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating white pill, icon-only; the active slot is a black circle with a
/// filled white glyph (reference screen E). Labels are provided to assistive
/// tech and as tooltips.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barH = 72;
  static const double _circle = 48;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            height: _barH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final slot = c.maxWidth / items.length;
                // Snap to whole pixels so the circle edge stays crisp.
                final dpr = MediaQuery.of(context).devicePixelRatio;
                double snap(double v) => (v * dpr).roundToDouble() / dpr;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      left: snap(slot * currentIndex + (slot - _circle) / 2),
                      top: snap((_barH - _circle) / 2),
                      width: _circle,
                      height: _circle,
                      child: const RepaintBoundary(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == currentIndex,
                              label: items[i].label,
                              child: Tooltip(
                                message: items[i].label,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onTap(i),
                                  child: SizedBox(
                                    height: _barH,
                                    child: Center(
                                      child: Icon(
                                        i == currentIndex
                                            ? items[i].activeIcon
                                            : items[i].icon,
                                        size: 24,
                                        color: i == currentIndex
                                            ? Colors.white
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
