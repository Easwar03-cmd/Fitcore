import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart' show apiErrorMessage;
import '../../auth/providers/auth_provider.dart';
import '../models/community_models.dart';
import 'community_provider.dart' show CommunityException;

/// Private daily to-do list. Stored per-user on the backend so it follows the
/// account to a new device; no screen or endpoint ever shows it to others.
final todoProvider =
    AsyncNotifierProvider.autoDispose<TodoNotifier, List<TodoItem>>(
        TodoNotifier.new);

class TodoNotifier extends AutoDisposeAsyncNotifier<List<TodoItem>> {
  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  Future<List<TodoItem>> build() async {
    if (ref.watch(authProvider).valueOrNull == null) return const [];
    return _fetch();
  }

  Future<List<TodoItem>> _fetch() async {
    try {
      final res = await _dio
          .get('/todo', queryParameters: {'date': localDateString()});
      final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return list
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> add(String title, {required bool repeatDaily}) async {
    try {
      await _dio.post('/todo', data: {
        'title': title.trim(),
        'date': localDateString(),
        'repeatDaily': repeatDaily,
      });
      state = AsyncData(await _fetch());
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> toggle(TodoItem item) async {
    final before = state.valueOrNull ?? const <TodoItem>[];
    // Optimistic update; roll back if the request fails.
    state = AsyncData([
      for (final t in before) t.id == item.id ? t.copyWith(done: !t.done) : t,
    ]);
    try {
      await _dio.patch('/todo/${item.id}', data: {'done': !item.done});
    } on DioException catch (e) {
      state = AsyncData(before);
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> remove(TodoItem item) async {
    final before = state.valueOrNull ?? const <TodoItem>[];
    state = AsyncData(before.where((t) => t.id != item.id).toList());
    try {
      await _dio.delete('/todo/${item.id}');
    } on DioException catch (e) {
      state = AsyncData(before);
      throw CommunityException(apiErrorMessage(e));
    }
  }
}
