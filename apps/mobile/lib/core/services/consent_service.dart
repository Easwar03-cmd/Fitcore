import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';

final _log = Logger();

/// Handles the AdMob User Messaging Platform (UMP) consent flow.
///
/// Call order:
///   1. [requestUpdate] — from main(), before MobileAds.initialize().
///      Fetches the latest consent status from Google's servers. No UI needed.
///   2. [showFormIfRequired] — from the first visible widget with a context
///      (ReviveApp.initState post-frame). Shows the consent form if the user
///      is in the EEA/UK and hasn't consented yet. No-op outside EEA.
class ConsentService {
  ConsentService._();

  /// Step 1 — call from main() before MobileAds.initialize().
  ///
  /// Fetches the user's consent status from Google UMP servers.
  /// Completes successfully even on network failure (fails silently so the
  /// app can still start and serve non-personalised ads).
  static Future<void> requestUpdate() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        _log.d('[Consent] Info update succeeded');
        completer.complete();
      },
      (FormError error) {
        _log.w('[Consent] Info update failed: ${error.message}');
        completer.complete(); // proceed; ads will be non-personalised
      },
    );
    return completer.future;
  }

  /// Step 2 — call once after the first frame is rendered (needs a context).
  ///
  /// Loads and shows the UMP consent form if:
  ///   - the user's consent status is [ConsentStatus.required] (EEA/UK), OR
  ///   - the status is [ConsentStatus.unknown] (first launch in some regions).
  ///
  /// On form dismissal MobileAds will automatically switch to personalised or
  /// non-personalised ads based on the choice. Outside EEA the form is never
  /// shown ([ConsentStatus.notRequired]).
  static Future<void> showFormIfRequired(BuildContext context) async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      _log.d('[Consent] Status: $status');

      if (status == ConsentStatus.notRequired) return;

      final formAvailable =
          await ConsentInformation.instance.isConsentFormAvailable();
      if (!formAvailable) return;

      final completer = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired(
        (FormError? formError) {
          if (formError != null) {
            _log.w('[Consent] Form error: ${formError.message}');
          }
          completer.complete();
        },
      );
      await completer.future;
    } catch (e) {
      _log.w('[Consent] showFormIfRequired failed: $e');
      // Proceed — app works with non-personalised ads if consent is absent.
    }
  }

  /// Whether the user has given (or is not required to give) consent.
  /// Used to gate personalised-ad features; non-personalised ads always show.
  static Future<bool> canShowPersonalisedAds() async {
    try {
      final status = await ConsentInformation.instance.getConsentStatus();
      return status == ConsentStatus.obtained ||
          status == ConsentStatus.notRequired;
    } catch (_) {
      return false;
    }
  }
}
