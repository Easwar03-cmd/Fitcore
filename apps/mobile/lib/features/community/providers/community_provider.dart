import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart' show apiErrorMessage;
import '../../auth/providers/auth_provider.dart';
import '../models/community_models.dart';

/// Thrown with a user-presentable message (the backend's own error text when
/// available) so screens can show it directly.
class CommunityException implements Exception {
  const CommunityException(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> _data(Response<dynamic> res) =>
    (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;

List<Map<String, dynamic>> _list(Response<dynamic> res) =>
    ((res.data as Map<String, dynamic>)['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

// ── Joined communities ────────────────────────────────────────────────────────

final communityListProvider =
    AsyncNotifierProvider<CommunityListNotifier, List<CommunitySummary>>(
        CommunityListNotifier.new);

class CommunityListNotifier extends AsyncNotifier<List<CommunitySummary>> {
  @override
  Future<List<CommunitySummary>> build() async {
    if (ref.watch(authProvider).valueOrNull == null) return const [];
    return _fetch();
  }

  Future<List<CommunitySummary>> _fetch() async {
    try {
      final res = await ref.read(apiClientProvider).dio.get('/community/mine');
      return _list(res).map(CommunitySummary.fromJson).toList();
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  /// Returns the new community id.
  Future<String> create({
    required String name,
    String? description,
    required bool isPublic,
  }) async {
    try {
      final res = await ref.read(apiClientProvider).dio.post('/community', data: {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'isPublic': isPublic,
      });
      await refresh();
      return _data(res)['id'] as String;
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  /// Join by invite [code] or public [communityId]. Returns the resulting
  /// membership status (`active` or `pending`).
  Future<String> join({String? code, String? communityId}) async {
    try {
      final res = await ref.read(apiClientProvider).dio.post('/community/join', data: {
        if (code != null) 'code': code.trim(),
        if (communityId != null) 'communityId': communityId,
      });
      await refresh();
      return _data(res)['status'] as String;
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }
}

// ── Search / invite preview ───────────────────────────────────────────────────

final communitySearchProvider = FutureProvider.autoDispose
    .family<List<CommunitySearchResult>, String>((ref, query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  try {
    final res = await ref
        .read(apiClientProvider)
        .dio
        .get('/community/search', queryParameters: {'q': q});
    return _list(res).map(CommunitySearchResult.fromJson).toList();
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

final invitePreviewProvider = FutureProvider.autoDispose
    .family<CommunitySearchResult, String>((ref, code) async {
  try {
    final res = await ref
        .read(apiClientProvider)
        .dio
        .get('/community/invite/${Uri.encodeComponent(code)}');
    return CommunitySearchResult.fromJson(_data(res));
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

// ── One community ─────────────────────────────────────────────────────────────

final communityDetailProvider =
    FutureProvider.autoDispose.family<CommunityDetail, String>((ref, id) async {
  try {
    final res = await ref.read(apiClientProvider).dio.get('/community/$id');
    return CommunityDetail.fromJson(_data(res));
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

final communityMembersProvider = FutureProvider.autoDispose
    .family<List<CommunityMemberInfo>, String>((ref, id) async {
  try {
    final res = await ref.read(apiClientProvider).dio.get('/community/$id/members');
    return _list(res).map(CommunityMemberInfo.fromJson).toList();
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

typedef MemberKey = ({String communityId, String userId});

final memberReportProvider =
    FutureProvider.autoDispose.family<MemberReport, MemberKey>((ref, key) async {
  try {
    final res = await ref
        .read(apiClientProvider)
        .dio
        .get('/community/${key.communityId}/members/${key.userId}/report');
    return MemberReport.fromJson(_data(res));
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

// ── Mutations ─────────────────────────────────────────────────────────────────

final communityActionsProvider =
    Provider<CommunityActions>((ref) => CommunityActions(ref));

class CommunityActions {
  CommunityActions(this._ref);
  final Ref _ref;

  Dio get _dio => _ref.read(apiClientProvider).dio;

  Future<void> _run(Future<Object?> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> updateSettings(String id, Map<String, Object?> patch) async {
    await _run(() => _dio.patch('/community/$id', data: patch));
    _ref.invalidate(communityDetailProvider(id));
    await _ref.read(communityListProvider.notifier).refresh();
  }

  Future<String> regenerateInvite(String id) async {
    try {
      final res = await _dio.post('/community/$id/invite/regenerate');
      _ref.invalidate(communityDetailProvider(id));
      return _data(res)['inviteCode'] as String;
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  Future<void> leave(String id) async {
    await _run(() => _dio.post('/community/$id/leave'));
    await _ref.read(communityListProvider.notifier).refresh();
  }

  Future<void> deleteCommunity(String id) async {
    await _run(() => _dio.delete('/community/$id'));
    await _ref.read(communityListProvider.notifier).refresh();
  }

  Future<void> setConsent(String id, {required bool share}) async {
    await _run(() => _dio.patch('/community/$id/members/me/consent', data: {'share': share}));
    _ref.invalidate(communityDetailProvider(id));
    _ref.invalidate(communityMembersProvider(id));
  }

  Future<void> memberAction(String id, String userId, String action) async {
    // action: approve | hold | resume
    await _run(() => _dio.post('/community/$id/members/$userId/$action'));
    _ref.invalidate(communityMembersProvider(id));
  }

  Future<void> removeMember(String id, String userId) async {
    await _run(() => _dio.delete('/community/$id/members/$userId'));
    _ref.invalidate(communityMembersProvider(id));
  }

  Future<void> deleteTrackingRecord(String id, String userId) async {
    await _run(() => _dio.delete('/community/$id/members/$userId/record'));
    _ref.invalidate(communityMembersProvider(id));
    _ref.invalidate(memberReportProvider((communityId: id, userId: userId)));
  }

  Future<void> report({
    String? messageId,
    String? communityId,
    String? userId,
    required String reason,
  }) =>
      _run(() => _dio.post('/community/report', data: {
            if (messageId != null) 'messageId': messageId,
            if (communityId != null) 'communityId': communityId,
            if (userId != null) 'userId': userId,
            'reason': reason,
          }));

  Future<void> blockUser(String userId) =>
      _run(() => _dio.post('/community/block', data: {'userId': userId}));
}
