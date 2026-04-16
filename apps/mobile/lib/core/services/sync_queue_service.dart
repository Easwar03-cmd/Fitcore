import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../api/api_client.dart';
import '../db/app_database.dart';
import 'notification_service.dart';
import 'sync_status_provider.dart';

final _log = Logger();

// Backoff delays indexed by current retryCount at time of failure.
// retryCount=0 → first failure → wait 5 s
// retryCount=1 → second failure → wait 30 s
// retryCount=2 → third failure → wait 5 min
// retryCount=3 → fourth failure → wait 30 min
// retryCount=4 → fifth failure → permanently failed (notify + delete)
const _kBackoffDelays = [
  Duration(seconds: 5),
  Duration(seconds: 30),
  Duration(minutes: 5),
  Duration(minutes: 30),
];

// ── SyncService ───────────────────────────────────────────────────────────────

class SyncService {
  SyncService(this._ref) {
    _setupLifecycleListener();
    _setupConnectivityListener();
  }

  final Ref _ref;
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// True when the last known connectivity state was offline, so we can
  /// trigger a flush only on the offline→online transition.
  bool _wasOffline = false;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  // ── Setup ─────────────────────────────────────────────────────────────────

  void _setupLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(onResume: flush);
  }

  void _setupConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline && _wasOffline) {
          _log.d('SyncService ▶ connectivity restored — flushing queue');
          flush();
        }
        _wasOffline = !isOnline;
      },
    );
  }

  void dispose() {
    _lifecycleListener?.dispose();
    _connectivitySub?.cancel();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Enqueue a write operation for offline retry.
  /// [httpMethod] is 'POST' (default) or 'DELETE'.
  /// For DELETE, embed the resource ID in [endpoint] and pass an empty map.
  Future<void> enqueue(
    String endpoint,
    Map<String, dynamic> payload, {
    String httpMethod = 'POST',
  }) async {
    await _db.syncDao.enqueue(
      endpoint,
      jsonEncode(payload),
      httpMethod: httpMethod,
    );
    _log.d('SyncService ▶ enqueued $httpMethod $endpoint');
    await _ref.read(syncStatusProvider.notifier).refreshCount();
  }

  /// Process every due item in FIFO order.
  /// Items that fail are rescheduled with exponential backoff.
  /// An item that exhausts all 4 retries is deleted and the user is notified.
  Future<void> flush() async {
    final notifier = _ref.read(syncStatusProvider.notifier);
    if (_ref.read(syncStatusProvider).isSyncing) return;

    final due = await _db.syncDao.getDueItems();
    if (due.isEmpty) return;

    notifier.setIsSyncing(true);
    _log.d('SyncService ▶ flushing ${due.length} due item(s)');

    final dio = _ref.read(apiClientProvider).dio;

    for (final item in due) {
      try {
        if (item.httpMethod == 'DELETE') {
          await dio.delete(item.endpoint);
        } else {
          final body = jsonDecode(item.payloadJson) as Map<String, dynamic>;
          await dio.post(item.endpoint, data: body);
        }
        await _db.syncDao.deleteById(item.id);
        notifier.recordSync();
        _log.d(
          'SyncService ▶ synced ${item.httpMethod} ${item.endpoint} '
          '(id=${item.id})',
        );
      } catch (e) {
        final nextCount = item.retryCount + 1;
        if (nextCount > _kBackoffDelays.length) {
          // All retries exhausted — drop the item and notify the user.
          await _db.syncDao.deleteById(item.id);
          _log.e(
            'SyncService ▶ permanently failed ${item.endpoint} '
            '(id=${item.id}): $e',
          );
          NotificationService.instance
              .showSyncFailedNotification(item.endpoint);
        } else {
          final delay = _kBackoffDelays[item.retryCount];
          final retryAfter = DateTime.now().add(delay);
          await _db.syncDao.markRetry(item.id, retryAfter, nextCount);
          _log.w(
            'SyncService ▶ retry $nextCount for ${item.endpoint} '
            'after $delay (id=${item.id}): $e',
          );
        }
        // Continue processing independent items even after a failure.
      }
    }

    notifier.setIsSyncing(false);
    await notifier.refreshCount();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Non-autoDispose so the service persists for the full app lifetime.
/// Initialise it once with [ref.read] from [ZenfitApp.initState].
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});
