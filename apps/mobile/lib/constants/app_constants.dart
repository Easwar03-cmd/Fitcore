abstract final class AppConstants {
  /// API base URL.
  ///
  /// Override at build time with --dart-define=FLUTTER_API_URL=<url>
  /// If not supplied falls back to the GCP Cloud Run production URL.
  static const String apiBaseUrl = String.fromEnvironment(
    'FLUTTER_API_URL',
    defaultValue: 'https://zenfit-api-122167595419.us-central1.run.app',
  );
}
