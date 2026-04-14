abstract final class AppConstants {
  /// API base URL.
  ///
  /// Override at build time with --dart-define=FLUTTER_API_URL=<url>
  /// If not supplied:
  ///   - debug / profile builds → http://localhost:3000
  ///   - release builds         → your Railway deployment URL
  static const String apiBaseUrl = String.fromEnvironment(
    'FLUTTER_API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://fitcore-api.up.railway.app'
        : 'http://localhost:3000',
  );
}
