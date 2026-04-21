import 'dart:convert';

import 'package:dio/dio.dart';
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
  String _historyKey(String userId) => 'coach_history_$userId';

  @override
  List<ChatMessage> build() {
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey(userId));
      if (raw == null) {
        // Fresh session — inject local greeting, no API call needed.
        _injectGreeting(firstName);
        return;
      }
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromStorageJson(e as Map<String, dynamic>))
          .toList();
      // If saved history only contains a stale greeting, refresh it.
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey(userId),
        jsonEncode(toSave.map((m) => m.toStorageJson()).toList()),
      );
    } catch (e) {
      _log.w('Failed to save coach history to prefs', error: e);
    }
  }

  Future<void> clearHistory() async {
    final auth = ref.read(authProvider).valueOrNull;
    if (auth != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey(auth.user.id));
      // Re-inject a fresh greeting after clearing.
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

    // Only non-local messages are sent as history so the AI gets real turns.
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

      final data = res.data!['data'] as Map<String, dynamic>;
      final coachMsg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.coach,
        text: data['reply'] as String,
        timestamp: DateTime.now(),
      );

      final updated = [...state, coachMsg];
      state = updated;
      await _saveHistory(updated);
    } on DioException catch (e) {
      state = state.where((m) => m.id != userMsg.id).toList();

      if (e.response?.statusCode == 503) {
        final body = e.response?.data as Map<String, dynamic>?;
        final msg = (body?['error'] as Map<String, dynamic>?)?['message'] as String?;
        throw CoachUnavailableException(
          msg ?? 'Coach is a bit busy right now. Please try again in a moment.',
        );
      }

      final body = e.response?.data as Map<String, dynamic>?;
      final serverMsg = (body?['error'] as Map<String, dynamic>?)?['message'] as String?;
      if (serverMsg != null) throw CoachUnavailableException(serverMsg);

      _log.e('CoachNotifier.sendMessage DioException', error: e);
      rethrow;
    } catch (e, st) {
      state = state.where((m) => m.id != userMsg.id).toList();
      _log.e('CoachNotifier.sendMessage failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
