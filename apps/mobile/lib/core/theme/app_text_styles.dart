
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Plus Jakarta Sans (bundled variable font) — see design.md §3.2.
abstract final class AppTextStyles {
  static const fontFamily = 'PlusJakartaSans';

  static TextStyle _s(
    double size,
    double weight, {
    double height = 1.3,
    double letterSpacing = 0,
    Color color = AppColors.ink,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: _fw(weight),
        fontVariations: [FontVariation('wght', weight)],
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static FontWeight _fw(double w) => w >= 700
      ? FontWeight.w700
      : w >= 600
          ? FontWeight.w600
          : w >= 500
              ? FontWeight.w500
              : FontWeight.w400;

  // ── Design tokens ───────────────────────────────────────────────────────────
  static final display = _s(30, 700, height: 1.1, letterSpacing: -0.5);
  static final title = _s(26, 500, height: 1.15, letterSpacing: -0.3);
  static final metricXL = _s(44, 500, height: 1.0, letterSpacing: -0.5);
  static final metricL = _s(28, 500, height: 1.0);
  static final metricM = _s(20, 700, height: 1.1);
  static final heading = _s(16, 700, height: 1.25);
  static final body = _s(14, 400, height: 1.4);
  static final bodyStrong = _s(14, 600, height: 1.4);
  static final caption = _s(12, 400, color: AppColors.inkMuted);
  static final micro = _s(11, 500, height: 1.2, letterSpacing: 0.1);
  static final headerTitle = _s(14, 500, height: 1.2);

  // ── Legacy names (mapped onto the tokens above) ─────────────────────────────
  static final displayLarge = display;
  static final displayMedium = _s(28, 600, height: 1.15, letterSpacing: -0.3);
  static final headlineLarge = _s(24, 500, height: 1.2, letterSpacing: -0.3);
  static final headlineMedium = _s(20, 600, height: 1.2);
  static final titleLarge = _s(18, 700, height: 1.25);
  static final titleMedium = heading;
  static final bodyLarge = _s(16, 400, height: 1.4);
  static final bodyMedium = body;
  static final bodySmall = caption;
  static final labelLarge = _s(14, 600, height: 1.2);
  static final labelSmall = micro;
}
