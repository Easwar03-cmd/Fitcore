import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../constants/app_constants.dart';
import '../../../core/api/token_store.dart';
import '../../../core/services/notification_service.dart';
import '../models/auth_state.dart';

const _kRefreshTokenKey = 'refresh_token';
const _storage = FlutterSecureStorage();

class AuthNotifier extends AsyncNotifier<AuthState?> {
  late final Dio _authDio;

  @override
  Future<AuthState?> build() async {
    // Plain Dio — no Bearer interceptor. Used for all auth endpoints.
    _authDio = Dio(
      BaseOptions(
        baseUrl:
            '${dotenv.env['FLUTTER_API_URL'] ?? AppConstants.apiBaseUrl}/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    ref.onDispose(_authDio.close);
    return _tryRestoreSession();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final res = await _authDio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      state = AsyncData(await _storeTokens(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e, st) {
      state = AsyncError(_extractError(e), st);
    } catch (e, st) {
      state = AsyncError(Exception('Login failed. Please try again.'), st);
    }
  }

  Future<void> signup(String email, String name, String password) async {
    state = const AsyncLoading();
    try {
      final res = await _authDio.post(
        '/auth/signup',
        data: {'email': email, 'name': name, 'password': password},
      );
      state = AsyncData(await _storeTokens(res.data['data'] as Map<String, dynamic>));
    } on DioException catch (e, st) {
      state = AsyncError(_extractError(e), st);
    } catch (e, st) {
      state = AsyncError(Exception('Signup failed. Please try again.'), st);
    }
  }

  /// Called after onboarding completes to flip hasProfile in memory.
  /// Triggers RouterNotifier to redirect to /home.
  void markProfileComplete() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      AuthState(
        user: current.user.copyWith(hasProfile: true),
        accessToken: current.accessToken,
      ),
    );
  }

  Future<void> logout() async {
    try {
      final token = state.valueOrNull?.accessToken;
      if (token != null) {
        await _authDio.post(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (_) {
      // Best-effort — always clear locally.
    }
    await _clearSession();
    state = const AsyncData(null);
  }

  /// Called by the ApiClient interceptor on 401. Returns null if refresh fails
  /// (in which case the session has been cleared and user will be redirected).
  Future<AuthState?> refreshSession(String refreshToken) async {
    try {
      final res = await _authDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final newState = await _storeTokens(res.data['data'] as Map<String, dynamic>);
      state = AsyncData(newState);
      return newState;
    } catch (_) {
      await _clearSession();
      state = const AsyncData(null);
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<AuthState?> _tryRestoreSession() async {
    final rt = await _storage.read(key: _kRefreshTokenKey);
    if (rt == null) return null;
    try {
      final res = await _authDio.post(
        '/auth/refresh',
        data: {'refreshToken': rt},
      );
      return _storeTokens(res.data['data'] as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _kRefreshTokenKey);
      return null;
    }
  }

  Future<AuthState> _storeTokens(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final user = UserDto.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
    ref.read(accessTokenProvider.notifier).state = accessToken;

    // Register FCM token with the backend (best-effort, never blocks login).
    final apiBaseUrl =
        dotenv.env['FLUTTER_API_URL'] ?? AppConstants.apiBaseUrl;
    NotificationService.instance
        .registerFcmToken(accessToken, apiBaseUrl)
        .ignore();

    return AuthState(user: user, accessToken: accessToken);
  }

  Future<void> _clearSession() async {
    // Clear FCM token from backend before wiping local session.
    final token = state.valueOrNull?.accessToken;
    if (token != null) {
      final apiBaseUrl =
          dotenv.env['FLUTTER_API_URL'] ?? AppConstants.apiBaseUrl;
      NotificationService.instance.clearFcmToken(token, apiBaseUrl).ignore();
    }
    await _storage.delete(key: _kRefreshTokenKey);
    ref.read(accessTokenProvider.notifier).state = null;
  }

  static Exception _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final msg = error['message'] as String?;
        if (msg != null) return Exception(msg);
      }
    }
    return Exception('Request failed. Please try again.');
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState?>(AuthNotifier.new);
