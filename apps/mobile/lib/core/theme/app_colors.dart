import 'package:flutter/material.dart';

/// Revive colour tokens — "pastel bento" palette (see design.md §3.1).
/// Light theme only.
abstract final class AppColors {
  // ── Neutrals ────────────────────────────────────────────────────────────────
  static const bg = Color(0xFFF2F2F2);
  static const bgAlt = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFEFEF);
  static const ink = Color(0xFF111111);
  static const inkMuted = Color(0xFF6B6B6B);
  static const hairline = Color(0x14000000);
  static const track = Color(0xFFE6E6E6);

  // ── Pastels ─────────────────────────────────────────────────────────────────
  static const sky = Color(0xFFB8E3EE);
  static const lime = Color(0xFFCFE8B8);
  static const butter = Color(0xFFFBE28C);
  static const salmon = Color(0xFFE1A38A);

  // ── Accents ─────────────────────────────────────────────────────────────────
  /// AA-safe teal for chips / small text on white.
  static const teal = Color(0xFF2F7E94);
  /// Reference teal for graphics (gauge arcs, outlines).
  static const tealBright = Color(0xFF4C98B0);
  static const coral = Color(0xFFE26A5E);
  /// Coral that passes AA as small text.
  static const coralText = Color(0xFFC94A3F);
  static const alertDot = Color(0xFFF28C28);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const success = Color(0xFF5E9B4C);
  static const warning = Color(0xFFD9A400);
  static const error = coralText;
  static const info = tealBright;

  // ── Macros ──────────────────────────────────────────────────────────────────
  static const protein = tealBright;
  static const carbs = Color(0xFFE6B422);
  static const fat = coral;
  static const calories = ink;

  // ── Legacy aliases (kept so unmigrated screens still compile; each maps to
  //    the new light palette). Prefer the tokens above in new code. ───────────
  static const primary = ink;
  static const primaryDark = ink;
  static const secondary = teal;
  static const background = bg;
  static const surfaceVariant = surfaceMuted;
  static const onBackground = ink;
  static const onSurface = ink;
  static const onSurfaceVariant = inkMuted;
  static const lightBackground = bg;
  static const lightSurface = surface;
  static const lightSurfaceVariant = surfaceMuted;
  static const lightOnBackground = ink;
  static const lightOnSurface = ink;
  static const lightOnSurfaceVariant = inkMuted;
}

/// Tint choices for pastel cards, pills and chips.
enum PastelTint { sky, lime, butter, salmon, grey, white }

extension PastelTintColor on PastelTint {
  Color get color => switch (this) {
        PastelTint.sky => AppColors.sky,
        PastelTint.lime => AppColors.lime,
        PastelTint.butter => AppColors.butter,
        PastelTint.salmon => AppColors.salmon,
        PastelTint.grey => AppColors.surfaceMuted,
        PastelTint.white => AppColors.surface,
      };
}
