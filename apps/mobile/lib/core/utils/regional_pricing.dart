import 'dart:io';

import 'package:intl/intl.dart';

/// Detects the device locale and returns the appropriate subscription prices
/// formatted in the user's regional currency.
///
/// Android: prices come directly from Google Play (already regional).
/// iOS: Stripe charges in USD but we show the local equivalent here.
class RegionalPricing {
  const RegionalPricing._({
    required this.countryCode,
    required this.currencyCode,
    required this.stripeLocale,
    required this.proDisplay,
    required this.coachDisplay,
    required this.isApproximate,
  });

  final String countryCode;
  final String currencyCode;

  /// BCP-47 locale string accepted by Stripe's `locale` parameter.
  final String stripeLocale;

  /// Formatted price string shown on the paywall for Pro tier.
  final String proDisplay;

  /// Formatted price string shown on the paywall for Coach tier.
  final String coachDisplay;

  /// True for any non-USD region — UI shows an "approx." disclaimer.
  final bool isApproximate;

  static RegionalPricing? _instance;

  /// Returns the regional pricing for the current device locale.
  /// Result is cached after the first call.
  static RegionalPricing detect() => _instance ??= _resolve();

  static RegionalPricing _resolve() {
    // Platform.localeName returns e.g. "en_IN", "en-US", "de_DE"
    final raw = Platform.localeName;
    final normalised = raw.replaceAll('-', '_');
    final parts = normalised.split('_');
    final country = parts.length >= 2 ? parts[1].toUpperCase() : 'US';
    final locale = normalised;
    return _build(country, locale);
  }

  static RegionalPricing _build(String country, String locale) {
    // (currencyCode, proAmount, coachAmount)
    final (String code, double pro, double coach) = _priceFor(country);
    final isUsd = code == 'USD';

    final fmt = NumberFormat.simpleCurrency(locale: locale, name: code);
    final proDisplay = _format(fmt, pro, code);
    final coachDisplay = _format(fmt, coach, code);

    // Derive a safe Stripe locale (language_COUNTRY → language)
    final langParts = locale.split('_');
    final stripeLocale = langParts.first.toLowerCase();

    return RegionalPricing._(
      countryCode: country,
      currencyCode: code,
      stripeLocale: stripeLocale,
      proDisplay: proDisplay,
      coachDisplay: coachDisplay,
      isApproximate: !isUsd,
    );
  }

  /// Maps a country code to (currencyCode, pro, coach) amounts.
  static (String, double, double) _priceFor(String country) {
    return switch (country) {
      // South Asia
      'IN' => ('INR', 829.0, 1649.0),
      'PK' => ('PKR', 2799.0, 5599.0),
      'LK' => ('LKR', 3199.0, 6399.0),
      'BD' => ('BDT', 1099.0, 2199.0),

      // East Asia
      'JP' => ('JPY', 1490.0, 2990.0),
      'KR' => ('KRW', 13900.0, 27900.0),
      'CN' => ('CNY', 69.0, 139.0),
      'TW' => ('TWD', 299.0, 599.0),
      'HK' => ('HKD', 79.0, 159.0),

      // Southeast Asia
      'SG' => ('SGD', 13.49, 26.99),
      'MY' => ('MYR', 44.99, 89.99),
      'ID' => ('IDR', 149000.0, 299000.0),
      'TH' => ('THB', 349.0, 699.0),
      'PH' => ('PHP', 569.0, 1139.0),
      'VN' => ('VND', 249000.0, 499000.0),

      // Middle East
      'AE' || 'SA' || 'KW' || 'QA' || 'BH' || 'OM' =>
        ('AED', 36.99, 73.99),

      // Oceania
      'AU' => ('AUD', 14.99, 29.99),
      'NZ' => ('NZD', 16.99, 33.99),

      // North America
      'CA' => ('CAD', 13.49, 26.99),
      'MX' => ('MXN', 169.0, 339.0),

      // South America
      'BR' => ('BRL', 49.99, 99.99),
      'AR' => ('ARS', 8999.0, 17999.0),
      'CO' => ('COP', 39900.0, 79900.0),
      'CL' => ('CLP', 9490.0, 18990.0),

      // Europe — Euro zone
      'DE' ||
      'FR' ||
      'IT' ||
      'ES' ||
      'NL' ||
      'PT' ||
      'BE' ||
      'AT' ||
      'FI' ||
      'IE' ||
      'GR' ||
      'PL' ||
      'CZ' ||
      'HU' ||
      'RO' ||
      'SK' ||
      'HR' ||
      'BG' ||
      'SI' ||
      'LU' ||
      'MT' ||
      'CY' ||
      'EE' ||
      'LV' ||
      'LT' =>
        ('EUR', 9.49, 18.99),

      // Europe — non-Euro
      'GB' => ('GBP', 7.99, 15.99),
      'SE' => ('SEK', 109.0, 219.0),
      'NO' => ('NOK', 109.0, 219.0),
      'DK' => ('DKK', 69.0, 139.0),
      'CH' => ('CHF', 9.49, 18.99),

      // Africa
      'ZA' => ('ZAR', 179.0, 359.0),
      'NG' => ('NGN', 8499.0, 16999.0),
      'KE' => ('KES', 1299.0, 2599.0),
      'GH' => ('GHS', 119.0, 239.0),

      // Default / US
      _ => ('USD', 9.99, 19.99),
    };
  }

  /// Formats a price amount, stripping unnecessary decimal places for
  /// currencies that don't use cents (JPY, KRW, IDR, etc.).
  static String _format(NumberFormat fmt, double amount, String code) {
    const noDecimal = {'JPY', 'KRW', 'IDR', 'VND', 'CLP', 'NGN'};
    if (noDecimal.contains(code)) {
      fmt.minimumFractionDigits = 0;
      fmt.maximumFractionDigits = 0;
    }
    return fmt.format(amount);
  }
}
