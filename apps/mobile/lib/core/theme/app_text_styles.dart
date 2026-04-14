import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const _base = TextStyle(fontFamily: 'Inter');

  static final displayLarge = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700);
  static final displayMedium = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700);
  static final headlineLarge = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w600);
  static final headlineMedium = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
  static final titleLarge = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static final titleMedium = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w500);
  static final bodyLarge = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static final bodyMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);
  static final labelLarge = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static final labelSmall = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);
}
