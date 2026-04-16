import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/chat_message.dart';

final _log = Logger();

// ─── State ────────────────────────────────────────────────────────────────────

class CoachState {
  const CoachState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.remainingMessages,
    this.isRateLimited = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  /// null = unlimited (pro/coach tier). int = messages left today (free tier).
  final int? remainingMessages;
  final bool isRateLimited;

  CoachState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    Object? remainingMessages = _sentinel,
    bool? isRateLimited,
  }) =>
      CoachState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        remainingMessages: remainingMessages == _sentinel
            ? this.remainingMessages
            : remainingMessages as int?,
        isRateLimited: isRateLimited ?? this.isRateLimited,
      );
}

// Sentinel lets copyWith distinguish "pass null intentionally" from "omit field".
const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CoachNotifier extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState();

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
      isRateLimited: false,
    );

    try {
      final client = ref.read(apiClientProvider);

      // Send full conversation history so the backend can pass it to Claude.
      final history = state.messages.map((m) => m.toJson()).toList();
      final res = await client.dio.post<Map<String, dynamic>>(
        '/ai/coach',
        data: {'messages': history},
      );

      final body = res.data;
      if (body != null && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final assistantMsg = ChatMessage(
          role: MessageRole.assistant,
          content: data['message'] as String,
          createdAt: DateTime.now(),
        );
        final remaining = data['remainingMessages'] as int?;
        state = state.copyWith(
          messages: [...state.messages, assistantMsg],
          isLoading: false,
          remainingMessages: remaining,
        );
      } else {
        final errorMsg =
            (body?['error'] as Map<String, dynamic>?)?['message'] as String? ??
                'Something went wrong';
        state = state.copyWith(isLoading: false, error: errorMsg);
      }
    } on DioException catch (e) {
      final code =
          (e.response?.data as Map<String, dynamic>?)?['error']
              ?['code'] as String?;
      if (code == 'RATE_LIMITED_COACH') {
        state = state.copyWith(
          isLoading: false,
          isRateLimited: true,
          error:
              'Daily message limit reached. Upgrade to Pro for unlimited coaching.',
        );
      } else {
        _log.e('Coach send failed', error: e);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get response. Please try again.',
        );
      }
    } catch (e, st) {
      _log.e('Coach send failed', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get response. Please try again.',
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final coachProvider =
    NotifierProvider<CoachNotifier, CoachState>(CoachNotifier.new);
