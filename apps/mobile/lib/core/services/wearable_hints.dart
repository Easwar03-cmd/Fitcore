/// Recognises a watch brand from its Bluetooth name / manufacturer string and
/// says how to get its data into Health Connect, which is the route that works
/// for every brand (their own app writes to it).
///
/// Brands stream health data over private, often encrypted, protocols, so
/// Revive only talks to a watch directly when it exposes the standard
/// Bluetooth Heart Rate service. Everything else goes through Health Connect.
class WearableHint {
  const WearableHint(this.brand, this.steps);
  final String brand;
  final String steps;
}

const _generic = WearableHint(
  'your watch',
  'Open your watch\'s own app, find the Health Connect option in its settings '
      'and allow it to write heart rate, sleep and steps.',
);

final _brands = <(RegExp, WearableHint)>[
  (
    RegExp(r'galaxy|samsung', caseSensitive: false),
    const WearableHint('Samsung',
        'In Samsung Health open Settings → Health Connect and allow heart rate, sleep and steps.'),
  ),
  (
    RegExp(r'fitbit|charge|inspire|versa|sense', caseSensitive: false),
    const WearableHint('Fitbit',
        'Fitbit syncs to Health Connect from the Fitbit app → Settings → Health Connect.'),
  ),
  (
    RegExp(r'garmin|forerunner|fenix|vivo|venu|instinct', caseSensitive: false),
    const WearableHint('Garmin',
        'In Garmin Connect open Settings → Connected apps → Health Connect and turn it on.'),
  ),
  (
    RegExp(r'mi (smart )?band|mi watch|xiaomi|redmi|amazfit|zepp|huami',
        caseSensitive: false),
    const WearableHint('Xiaomi / Amazfit',
        'In Mi Fitness or Zepp open Profile → Health Connect (Data sharing) and allow it.'),
  ),
  (
    RegExp(r'oneplus|oppo|realme|heytap|enco|oraimo', caseSensitive: false),
    const WearableHint('OnePlus / OPPO / realme',
        'In HeyTap Health (OnePlus Health) open Settings → Data sharing → Health Connect and allow it.'),
  ),
  (
    RegExp(r'huawei|honor', caseSensitive: false),
    const WearableHint('Huawei / Honor',
        'Huawei Health shares to Health Connect from Settings → Data sharing, where your region supports it.'),
  ),
  (
    RegExp(r'pixel watch|wear os|ticwatch|fossil', caseSensitive: false),
    const WearableHint('Wear OS',
        'Your watch app already shares with Health Connect — open Health Connect and allow Revive.'),
  ),
  (
    RegExp(r'noise|boat|fire-?boltt|gizmore|pebble', caseSensitive: false),
    const WearableHint('Noise / boAt / Fire-Boltt',
        'Open the watch\'s app and look for Health Connect or Google Fit sync; if it has neither, '
            'it cannot share data with other apps.'),
  ),
];

WearableHint hintFor(String deviceName, {String? manufacturer}) {
  final text = '$deviceName ${manufacturer ?? ''}';
  for (final (pattern, hint) in _brands) {
    if (pattern.hasMatch(text)) return hint;
  }
  return _generic;
}
