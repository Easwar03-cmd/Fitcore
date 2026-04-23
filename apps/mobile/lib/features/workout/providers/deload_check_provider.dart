import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/deload_check.dart';

final _log = Logger();

final deloadCheckProvider =
    AsyncNotifierProvider<DeloadCheckNotifier, DeloadCheck?>(
        DeloadCheckNotifier.new);

class DeloadCheckNotifier extends AsyncNotifier<DeloadCheck?> {
  @override
  Future<DeloadCheck?> build() {
    if (ref.watch(authProvider).valueOrNull == null) return Future.value(null);
    return _fetch();
  }

  Future<DeloadCheck?> _fetch() async {
    try {
      final response =
          await ref.read(apiClientProvider).dio.get('/ai/deload-check');
      final data = response.data['data'] as Map<String, dynamic>;
      return DeloadCheck.fromJson(data);
    } catch (e, st) {
      _log.w('Could not load deload check', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
