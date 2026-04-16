import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../models/chat_message.dart';

part 'coach_provider.g.dart';

const _uuid = Uuid();
final _log = Logger();

// ─── Rate-limit state ─────────────────────────────────────────────────────────

/// Tracks how many coach messages the user has sent today and the daily cap.
/// Updated after every successful [CoachNotifier.sendMessage] call from the
/// payload returned by the server.
final coachRateLimitProvider = StateProvider<({int used, int limit})>(
  (ref) => (used: 0, limit: 5),
);

// ─── Exception ────────────────────────────────────────────────────────────────

class RateLimitException implements Exception {
  const RateLimitException(this.used, this.limit);

  final int used;
  final int limit;

  @override
  String toString() =>
      'Daily message limit reached: $used / $limit messages used today.';
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

@riverpod
class CoachNotifier extends _$CoachNotifier {
  @override
  List<ChatMessage> build() => const [];

  /// Sends [text] to the AI coach.
  ///
  /// 1. Appends the user message optimistically.
  /// 2. POSTs to `/ai/chat` via [apiClientProvider].
  /// 3. On success: appends the coach reply and updates [coachRateLimitProvider].
  /// 4. On HTTP 429: rolls back the optimistic message and throws [RateLimitException].
  /// 5. On any other error: rolls back the optimistic message and rethrows.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    // Optimistic insert.
    state = [...state, userMsg];

    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post<Map<String, dynamic>>(
            '/ai/chat',
            data: {'message': trimmed},
          );

      final body = res.data!;
      final data = body['data'] as Map<String, dynamic>;

      final coachMsg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.coach,
        text: data['reply'] as String,
        timestamp: DateTime.now(),
      );

      state = [...state, coachMsg];

      // Sync rate-limit counters from the server payload.
      final usedToday = data['messagesUsedToday'] as int?;
      final dailyLimit = data['dailyLimit'] as int?;
      if (usedToday != null) {
        final current = ref.read(coachRateLimitProvider);
        ref.read(coachRateLimitProvider.notifier).state = (
          used: usedToday,
          limit: dailyLimit ?? current.limit,
        );
      }
    } on DioException catch (e) {
      // Roll back optimistic message in all error paths.
      state = state.where((m) => m.id != userMsg.id).toList();

      if (e.response?.statusCode == 429) {
        final body = e.response?.data as Map<String, dynamic>?;
        // Backend puts rate-limit counters inside the `error` envelope, not `data`
        final errData = body?['error'] as Map<String, dynamic>?;
        final current = ref.read(coachRateLimitProvider);
        final used = errData?['messagesUsedToday'] as int? ?? current.used;
        final limit = errData?['limit'] as int? ?? current.limit;
        throw RateLimitException(used, limit);
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
