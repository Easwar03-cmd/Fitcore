import 'package:flutter/foundation.dart';

/// AdMob unit IDs. Non-release builds use Google's official test units —
/// loading or tapping live ads during development violates AdMob policy
/// and can get the account suspended.
abstract final class AdUnits {
  static const String interstitial = kReleaseMode
      ? 'ca-app-pub-3352385278044542/8100275469'
      : 'ca-app-pub-3940256099942544/1033173712';

  static const String homeBanner = kReleaseMode
      ? 'ca-app-pub-3352385278044542/3534344490'
      : 'ca-app-pub-3940256099942544/6300978111';

  static const String homePopup = kReleaseMode
      ? 'ca-app-pub-3352385278044542/3099230221'
      : 'ca-app-pub-3940256099942544/6300978111';
}
