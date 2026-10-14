import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart' show apiErrorMessage;
import '../models/community_models.dart';
import 'community_provider.dart'
    show CommunityException, communityListProvider;

Map<String, dynamic> _data(Response<dynamic> res) =>
    (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;

final challengeListProvider = FutureProvider.autoDispose
    .family<List<ChallengeSummary>, String>((ref, communityId) async {
  try {
    final res = await ref
        .read(apiClientProvider)
        .dio
        .get('/community/$communityId/challenges');
    final list = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return list
        .map((e) => ChallengeSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

/// A challenge together with the community it belongs to.
class CommunityChallenge {
  const CommunityChallenge(this.community, this.challenge);
  final CommunitySummary community;
  final ChallengeSummary challenge;
}

/// Challenges from every joined (approved) community, newest activity first
/// by open status then title.
final allChallengesProvider =
    FutureProvider.autoDispose<List<CommunityChallenge>>((ref) async {
  final communities = await ref.watch(communityListProvider.future);
  final active = communities.where((c) => !c.isPending).toList();
  final lists = await Future.wait(active.map((c) async {
    final items = await ref.watch(challengeListProvider(c.id).future);
    return [for (final ch in items) CommunityChallenge(c, ch)];
  }));
  final all = lists.expand((l) => l).toList()
    ..sort((a, b) {
      final ao = a.challenge.status == 'open' ? 0 : 1;
      final bo = b.challenge.status == 'open' ? 0 : 1;
      return ao != bo ? ao - bo : a.challenge.title.compareTo(b.challenge.title);
    });
  return all;
});

final challengeDetailProvider = FutureProvider.autoDispose
    .family<ChallengeDetail, String>((ref, challengeId) async {
  try {
    final res = await ref
        .read(apiClientProvider)
        .dio
        .get('/community/challenges/$challengeId');
    return ChallengeDetail.fromJson(_data(res));
  } on DioException catch (e) {
    throw CommunityException(apiErrorMessage(e));
  }
});

final challengeActionsProvider =
    Provider<ChallengeActions>((ref) => ChallengeActions(ref));

class ChallengeActions {
  ChallengeActions(this._ref);
  final Ref _ref;

  Dio get _dio => _ref.read(apiClientProvider).dio;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw CommunityException(apiErrorMessage(e));
    }
  }

  void _refresh(String communityId, String challengeId) {
    _ref.invalidate(challengeListProvider(communityId));
    _ref.invalidate(challengeDetailProvider(challengeId));
  }

  Future<String> create({
    required String communityId,
    required String kind,
    required String title,
    String? description,
    required int totalDays,
    String? notes,
  }) =>
      _run(() async {
        final res = await _dio.post('/community/$communityId/challenges', data: {
          'kind': kind,
          'title': title.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'totalDays': totalDays,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes,
          'clientDate': localDateString(),
        });
        _ref.invalidate(challengeListProvider(communityId));
        return _data(res)['id'] as String;
      });

  Future<void> join(String communityId, String challengeId) => _run(() async {
        await _dio.post('/community/challenges/$challengeId/join',
            data: {'clientDate': localDateString()});
        _refresh(communityId, challengeId);
      });

  Future<void> leave(String communityId, String challengeId) => _run(() async {
        await _dio.post('/community/challenges/$challengeId/leave');
        _refresh(communityId, challengeId);
      });

  /// Marks today complete. Returns true when this finished the challenge.
  Future<bool> markToday(String communityId, String challengeId) =>
      _run(() async {
        final res = await _dio.post('/community/challenges/$challengeId/checkins',
            data: {'date': localDateString()});
        _refresh(communityId, challengeId);
        return _data(res)['finished'] as bool;
      });

  Future<void> undoDay(String communityId, String challengeId, int day) =>
      _run(() async {
        await _dio.delete('/community/challenges/$challengeId/checkins/$day');
        _refresh(communityId, challengeId);
      });

  Future<void> saveNotes(String challengeId, String notes) => _run(() async {
        await _dio.patch('/community/challenges/$challengeId/notes',
            data: {'notes': notes});
      });

  Future<void> shareNotes(String challengeId) => _run(() async {
        await _dio.post('/community/challenges/$challengeId/share');
      });

  Future<void> close(String communityId, String challengeId) => _run(() async {
        await _dio.patch('/community/challenges/$challengeId',
            data: {'status': 'closed'});
        _refresh(communityId, challengeId);
      });

  Future<void> delete(String communityId, String challengeId) => _run(() async {
        await _dio.delete('/community/challenges/$challengeId');
        _ref.invalidate(challengeListProvider(communityId));
      });
}
