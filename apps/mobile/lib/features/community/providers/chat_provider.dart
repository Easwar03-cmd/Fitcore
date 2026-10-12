import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart' show apiErrorMessage;
import '../models/community_models.dart';
import 'community_provider.dart' show CommunityException;

final _log = Logger();

const _pollInterval = Duration(seconds: 3);

/// A file picked for attachment, already read from disk.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final List<int> bytes;
  final String fileName;
  final String contentType;
}

final chatProvider = AsyncNotifierProvider.autoDispose
    .family<ChatNotifier, List<CommunityMessage>, String>(ChatNotifier.new);

/// Message list for one community. Polls for new messages every 3 s while the
/// chat screen is mounted (autoDispose stops the timer when it is closed).
class ChatNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<CommunityMessage>, String> {
  Timer? _timer;
  bool _polling = false;

  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  Future<List<CommunityMessage>> build(String communityId) async {
    ref.onDispose(() => _timer?.cancel());
    final initial = await _fetch();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    return initial;
  }

  Future<List<CommunityMessage>> _fetch({DateTime? before, DateTime? after}) async {
    try {
      final res = await _dio.get('/community/$arg/messages', queryParameters: {
        if (before != null) 'before': before.toUtc().toIso8601String(),
        if (after != null) 'after': after.toUtc().toIso8601String(),
        'limit': 50,
      });
      final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return list
          .map((e) => CommunityMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> _poll() async {
    if (_polling) return;
    final current = state.valueOrNull;
    if (current == null) return;
    _polling = true;
    try {
      final after = current.isEmpty ? null : current.last.createdAt;
      final fresh = await _fetch(after: after);
      if (fresh.isEmpty) return;
      final known = current.map((m) => m.id).toSet();
      final added = fresh.where((m) => !known.contains(m.id)).toList();
      if (added.isNotEmpty) state = AsyncData([...current, ...added]);
    } catch (e) {
      _log.d('chat poll failed: $e'); // transient — next tick retries
    } finally {
      _polling = false;
    }
  }

  /// Older page, prepended. Returns false when there is nothing older.
  Future<bool> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return false;
    final older = await _fetch(before: current.first.createdAt);
    if (older.isEmpty) return false;
    state = AsyncData([...older, ...current]);
    return true;
  }

  Future<void> sendText(String text, {bool asUpdate = false, String? replyToId}) async {
    await _post({
      'kind': asUpdate ? 'update' : 'text',
      'body': text.trim(),
      if (replyToId != null) 'replyToId': replyToId,
    });
  }

  Future<void> sendAttachment(
    OutgoingAttachment file, {
    String? caption,
    String? replyToId,
  }) async {
    try {
      final signed = await _dio.post('/community/$arg/media/upload-url', data: {
        'contentType': file.contentType,
        'sizeBytes': file.bytes.length,
      });
      final d = (signed.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      // Direct upload to the signed URL — no auth header, so use a bare Dio.
      await Dio().put<void>(
        d['uploadUrl'] as String,
        data: Stream.fromIterable([file.bytes]),
        options: Options(headers: {
          'Content-Type': file.contentType,
          'Content-Length': file.bytes.length,
        }),
      );
      await _post({
        'kind': 'media',
        'mediaPath': d['objectPath'],
        'mediaType': d['mediaType'],
        'mediaName': file.fileName,
        if (caption != null && caption.trim().isNotEmpty) 'body': caption.trim(),
        if (replyToId != null) 'replyToId': replyToId,
      });
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> _post(Map<String, Object?> body) async {
    try {
      final res = await _dio.post('/community/$arg/messages', data: body);
      final msg = CommunityMessage.fromJson(
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
      final current = state.valueOrNull ?? const <CommunityMessage>[];
      if (!current.any((m) => m.id == msg.id)) {
        state = AsyncData([...current, msg]);
      }
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _dio.delete('/community/$arg/messages/$messageId');
      final current = state.valueOrNull ?? const <CommunityMessage>[];
      state = AsyncData([
        for (final m in current)
          if (m.id == messageId)
            CommunityMessage(
              id: m.id,
              kind: m.kind,
              author: m.author,
              createdAt: m.createdAt,
              deleted: true,
            )
          else
            m,
      ]);
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }
}
