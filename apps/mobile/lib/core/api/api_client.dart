import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'token_store.dart';

final _log = Logger();

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));

class ApiClient {
  ApiClient(Ref ref) {
    // dotenv overrides AppConstants (useful for local .env files during dev).
    // AppConstants provides the compile-time default (localhost in debug,
    // Railway URL in release), which itself can be overridden via
    // --dart-define=FLUTTER_API_URL=<url> at build time.
    final baseUrl =
        '${dotenv.env['FLUTTER_API_URL'] ?? AppConstants.apiBaseUrl}/api/v1';
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        // 90 s: AI endpoints retry up to 3× with 3 s / 6 s / 12 s backoff.
        // Regular endpoints finish well within this window.
        receiveTimeout: const Duration(seconds: 90),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(ref, baseUrl));
  }

  late final Dio _dio;

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref, this._baseUrl);

  final Ref _ref;
  final String _baseUrl;
  static const _storage = FlutterSecureStorage();
  bool _isRefreshing = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(accessTokenProvider);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final rt = await _storage.read(key: 'refresh_token');
      if (rt == null) {
        _ref.read(authProvider.notifier).logout();
        handler.next(err);
        return;
      }

      final newState =
          await _ref.read(authProvider.notifier).refreshSession(rt);

      if (newState == null) {
        handler.next(err);
        return;
      }

      // Retry original request with the new token.
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${newState.accessToken}';
      final retryDio = Dio(BaseOptions(baseUrl: _baseUrl));
      final retryRes = await retryDio.fetch(opts);
      handler.resolve(retryRes);
    } catch (e) {
      _log.e('Token refresh failed in interceptor', error: e);
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
