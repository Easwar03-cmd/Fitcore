import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { auto, light, dark }

class ThemeNotifier extends Notifier<ThemePreference> {
  static const _key = 'theme_pref';

  @override
  ThemePreference build() {
    _loadAsync();
    return ThemePreference.auto;
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    if (name != null) {
      state = ThemePreference.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ThemePreference.auto,
      );
    }
  }

  Future<void> setPreference(ThemePreference pref) async {
    state = pref;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pref.name);
  }
}

final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, ThemePreference>(ThemeNotifier.new);

/// Derives the active [ThemeMode] from user preference + current time.
/// When [ThemePreference.auto] is active, automatically schedules a rebuild
/// at the next 6 AM / 6 PM boundary so the switch happens without any
/// user interaction.
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final pref = ref.watch(themeNotifierProvider);

  if (pref == ThemePreference.auto) {
    final timer = Timer(_durationUntilNextBoundary(), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }

  return switch (pref) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark  => ThemeMode.dark,
    ThemePreference.auto  => _isNightTime() ? ThemeMode.dark : ThemeMode.light,
  };
});

bool _isNightTime() {
  final h = DateTime.now().hour;
  return h >= 18 || h < 6;
}

Duration _durationUntilNextBoundary() {
  final now = DateTime.now();
  final today6am = DateTime(now.year, now.month, now.day, 6);
  final today6pm = DateTime(now.year, now.month, now.day, 18);
  if (now.isBefore(today6am)) return today6am.difference(now);
  if (now.isBefore(today6pm)) return today6pm.difference(now);
  return today6am.add(const Duration(days: 1)).difference(now);
}
