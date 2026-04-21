import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand (same across both themes)
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4B44CC);
  static const secondary = Color(0xFF03DAC6);

  // Semantic (same across both themes)
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);
  static const error = Color(0xFFE53935);
  static const info = Color(0xFF2196F3);

  // Dark theme neutrals
  static const background = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceVariant = Color(0xFF252540);
  static const onBackground = Color(0xFFF5F5F5);
  static const onSurface = Color(0xFFE0E0E0);
  static const onSurfaceVariant = Color(0xFFAAAAAA);

  // Light theme neutrals
  static const lightBackground = Color(0xFFFAFAF8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF0F0F8);
  static const lightOnBackground = Color(0xFF1A1A2E);
  static const lightOnSurface = Color(0xFF2C2C3E);
  static const lightOnSurfaceVariant = Color(0xFF6B6B80);

  // Macros (same across both themes)
  static const protein = Color(0xFF5C6BC0);
  static const carbs = Color(0xFFFFB300);
  static const fat = Color(0xFFEF5350);
  static const calories = Color(0xFF6C63FF);
}
