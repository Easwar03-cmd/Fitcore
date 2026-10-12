import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Radius / spacing tokens (design.md §3.3).
abstract final class AppRadius {
  static const double hero = 28;
  static const double card = 24;
  static const double tile = 20;
  static const double input = 16;
  static const double pill = 999;
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Light-only theme. See design.md.
abstract final class AppTheme {
  static final _textTheme = TextTheme(
    displayLarge: AppTextStyles.displayLarge,
    displayMedium: AppTextStyles.displayMedium,
    displaySmall: AppTextStyles.title,
    headlineLarge: AppTextStyles.headlineLarge,
    headlineMedium: AppTextStyles.headlineMedium,
    headlineSmall: AppTextStyles.titleLarge,
    titleLarge: AppTextStyles.titleLarge,
    titleMedium: AppTextStyles.titleMedium,
    titleSmall: AppTextStyles.bodyStrong,
    bodyLarge: AppTextStyles.bodyLarge,
    bodyMedium: AppTextStyles.bodyMedium,
    bodySmall: AppTextStyles.bodySmall,
    labelLarge: AppTextStyles.labelLarge,
    labelMedium: AppTextStyles.micro,
    labelSmall: AppTextStyles.labelSmall,
  );

  static const _pill = StadiumBorder();

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      primaryContainer: AppColors.sky,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.lime,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.salmon,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.butter,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.coralText,
      onError: Colors.white,
      errorContainer: Color(0xFFFADAD6),
      onErrorContainer: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHigh: AppColors.surfaceMuted,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.inkMuted,
      outlineVariant: AppColors.hairline,
      shadow: Colors.black,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: scheme,
      textTheme: _textTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.headerTitle,
        iconTheme: const IconThemeData(color: AppColors.ink),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.coralText, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.coralText, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.inkMuted,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: _pill,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.inkMuted,
          minimumSize: const Size(0, 48),
          shape: _pill,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(0, 48),
          shape: _pill,
          side: const BorderSide(color: AppColors.hairline),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          shape: _pill,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.sky,
        disabledColor: AppColors.surfaceMuted,
        side: BorderSide.none,
        shape: _pill,
        labelStyle: AppTextStyles.micro.copyWith(fontSize: 12),
        secondaryLabelStyle:
            AppTextStyles.micro.copyWith(fontSize: 12, color: AppColors.ink),
        checkmarkColor: AppColors.ink,
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.track,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: const BorderSide(color: AppColors.inkMuted, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.ink : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(AppColors.ink),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.track,
        circularTrackColor: AppColors.track,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.ink,
        inactiveTrackColor: AppColors.track,
        thumbColor: AppColors.ink,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.hero),
        ),
        titleTextStyle: AppTextStyles.heading,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(_pill),
          side: WidgetStateProperty.all(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.surfaceMuted,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.ink,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTextStyles.micro.copyWith(color: Colors.white),
      ),
    );
  }
}
