import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the home-screen banner ad has been dismissed this session.
/// Automatically resets to false on cold start — Riverpod state is in-memory only.
final adBannerDismissedProvider = StateProvider<bool>((ref) => false);

/// Whether the home-screen popup ad has been dismissed this session.
/// Automatically resets to false on cold start — Riverpod state is in-memory only.
final adPopupDismissedProvider = StateProvider<bool>((ref) => false);
