import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';

part 'coach_provider.g.dart';

const _uuid = Uuid();
final _log = Logger();

// ─── Rate-limit state ─────────────────────────────────────────────────────────

final coachRateLimitProvider = StateProvider<({int used, int limit})>(
  (ref) => (used: 0, limit: 0),
);

// ─── Exceptions ───────────────────────────────────────────────────────────────

class RateLimitException implements Exception {
  const RateLimitException(this.used, this.limit);
  final int used;
  final int limit;
  @override
  String toString() => 'Daily message limit reached: $used / $limit messages used today.';
}

class CoachUnavailableException implements Exception {
  const CoachUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

@riverpod
class CoachNotifier extends _$CoachNotifier {
  // SharedPreferences key scoped to the current user so history is per-account.
  String _historyKey(String userId) => 'coach_history_$userId';

  @override
  List<ChatMessage> build() {
    // Kick off async load; state starts empty and updates when prefs are read.
    _loadHistory();
    return const [];
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final userId = ref.read(authProvider).valueOrNull?.user.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey(userId));
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromStorageJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (e) {
      _log.w('Failed to load coach history from prefs', error: e);
    }
  }

  Future<void> _saveHistory(List<ChatMessage> messages) async {
    final userId = ref.read(authProvider).valueOrNull?.user.id;
    if (userId == null) return;
    try {
      // Keep the last 100 messages to avoid unbounded growth.
      final toSave = messages.length > 100
          ? messages.sublist(messages.length - 100)
          : messages;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey(userId),
        jsonEncode(toSave.map((m) => m.toStorageJson()).toList()),
      );
    } catch (e) {
      _log.w('Failed to save coach history to prefs', error: e);
    }
  }

  /// Clears the conversation for the current user (both in memory and on disk).
  Future<void> clearHistory() async {
    final userId = ref.read(authProvider).valueOrNull?.user.id;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey(userId));
    }
    state = const [];
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

    // Capture history BEFORE the optimistic insert so we don't send the
    // in-flight user message as part of the history.
    final historySnapshot = state
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
    // Server accepts at most 20 history items.
    final history = historySnapshot.length > 20
        ? historySnapshot.sublist(historySnapshot.length - 20)
        : historySnapshot;

    // Optimistic insert.
    state = [...state, userMsg];

    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post<Map<String, dynamic>>(
            '/ai/chat',
            data: {'message': trimmed, 'history': history},
          );

      final body = res.data!;
      final data = body['data'] as Map<String, dynamic>;

      final coachMsg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.coach,
        text: data['reply'] as String,
        timestamp: DateTime.now(),
      );

      final updated = [...state, coachMsg];
      state = updated;

      // Persist after every successful exchange.
      await _saveHistory(updated);

      // Sync rate-limit counters from the server payload.
      final usedToday = data['messagesUsedToday'] as int?;
      final dailyLimit = data['dailyLimit'] as int?;
      if (usedToday != null) {
        ref.read(coachRateLimitProvider.notifier).state = (
          used: usedToday,
          limit: dailyLimit ?? ref.read(coachRateLimitProvider).limit,
        );
      }
    } on DioException catch (e) {
      // Roll back optimistic message in all error paths.
      state = state.where((m) => m.id != userMsg.id).toList();

      if (e.response?.statusCode == 429) {
        final body = e.response?.data as Map<String, dynamic>?;
        final errData = body?['error'] as Map<String, dynamic>?;
        final current = ref.read(coachRateLimitProvider);
        final used = errData?['messagesUsedToday'] as int? ?? current.used;
        final limit = errData?['limit'] as int? ?? current.limit;
        // Persist rate-limited state so the input bar disables immediately.
        ref.read(coachRateLimitProvider.notifier).state = (used: used, limit: limit);
        throw RateLimitException(used, limit);
      }

      if (e.response?.statusCode == 503) {
        final body = e.response?.data as Map<String, dynamic>?;
        final msg = (body?['error'] as Map<String, dynamic>?)?['message'] as String?;
        throw CoachUnavailableException(
          msg ?? 'AI service is temporarily unavailable. Please try again later.',
        );
      }

      // Surface the actual server error message if available.
      final body = e.response?.data as Map<String, dynamic>?;
      final serverMsg = (body?['error'] as Map<String, dynamic>?)?['message'] as String?;
      if (serverMsg != null) {
        throw CoachUnavailableException(serverMsg);
      }

      _log.e('CoachNotifier.sendMessage DioException', error: e);
      rethrow;
    } catch (e, st) {
      state = state.where((m) => m.id != userMsg.id).toList();
      _log.e('CoachNotifier.sendMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
