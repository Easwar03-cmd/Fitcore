import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';

part 'coach_provider.g.dart';

const _uuid = Uuid();
final _log = Logger();

// ─── Exceptions ───────────────────────────────────────────────────────────────

class CoachUnavailableException implements Exception {
  const CoachUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

@riverpod
class CoachNotifier extends _$CoachNotifier {
  static const _storage = FlutterSecureStorage();

  String _historyKey(String userId) => 'coach_history_$userId';

  @override
  List<ChatMessage> build() {
    // Watch so this rebuilds (and loads the correct history) when auth changes.
    ref.watch(authProvider);
    _loadHistory();
    return const [];
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final auth = ref.read(authProvider).valueOrNull;
    if (auth == null) return;
    final userId = auth.user.id;
    final firstName = auth.user.name.split(' ').first;

    try {
      final raw = await _storage.read(key: _historyKey(userId));
      if (raw == null) {
        _injectGreeting(firstName);
        return;
      }
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromStorageJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        state = list;
      } else {
        _injectGreeting(firstName);
      }
    } catch (e) {
      _log.w('Failed to load coach history from prefs', error: e);
      _injectGreeting(firstName);
    }
  }

  void _injectGreeting(String firstName) {
    state = [
      ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.coach,
        text: 'Hey $firstName! How can I help you today?',
        timestamp: DateTime.now(),
        isLocal: true,
      ),
    ];
  }

  Future<void> _saveHistory(List<ChatMessage> messages) async {
    final userId = ref.read(authProvider).valueOrNull?.user.id;
    if (userId == null) return;
    try {
      final toSave = messages.length > 100
          ? messages.sublist(messages.length - 100)
          : messages;
      await _storage.write(
        key: _historyKey(userId),
        value: jsonEncode(toSave.map((m) => m.toStorageJson()).toList()),
      );
    } catch (e) {
      _log.w('Failed to save coach history to prefs', error: e);
    }
  }

  Future<void> clearHistory() async {
    final auth = ref.read(authProvider).valueOrNull;
    if (auth != null) {
      await _storage.delete(key: _historyKey(auth.user.id));
      _injectGreeting(auth.user.name.split(' ').first);
    } else {
      state = const [];
    }
  }

  // ── Message send ─────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    final historySnapshot = state
        .where((m) => !m.isLocal)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
    final history = historySnapshot.length > 20
        ? historySnapshot.sublist(historySnapshot.length - 20)
        : historySnapshot;

    state = [...state, userMsg];

    try {
      final data = await _callWithRetry(trimmed, history);

      final coachMsg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.coach,
        text: data['reply'] as String,
        timestamp: DateTime.now(),
      );

      final updated = [...state, coachMsg];
      state = updated;
      await _saveHistory(updated);
    } catch (e, st) {
      // Roll back the user message only on final failure.
      state = state.where((m) => m.id != userMsg.id).toList();
      _log.e('CoachNotifier.sendMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Calls /ai/chat, silently retrying once after 4 s on 503.
  /// Always throws [CoachUnavailableException] on failure so the caller
  /// never has to deal with raw DioExceptions.
  Future<Map<String, dynamic>> _callWithRetry(
    String message,
    List<Map<String, dynamic>> history,
  ) async {
    Future<Map<String, dynamic>> doCall() async {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post<Map<String, dynamic>>(
            '/ai/chat',
            data: {'message': message, 'history': history},
          );
      return res.data!['data'] as Map<String, dynamic>;
    }

    DioException? lastDio;

    try {
      return await doCall();
    } on DioException catch (e) {
      lastDio = e;
    }

    // 503 = Gemini temporarily busy — retry once silently.
    if (lastDio.response?.statusCode == 503) {
      await Future.delayed(const Duration(seconds: 4));
      try {
        return await doCall();
      } on DioException catch (e) {
        lastDio = e;
      }
    }

    final body = lastDio.response?.data as Map<String, dynamic>?;
    final serverMsg = (body?['error'] as Map<String, dynamic>?)?['message'] as String?;
    throw CoachUnavailableException(
      serverMsg ?? 'Something went wrong. Please try again.',
    );
  }
}
