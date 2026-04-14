import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class SyncStatus {
  const SyncStatus({
    required this.pendingCount,
    required this.isSyncing,
    this.lastSyncedAt,
  });

  /// Number of operations waiting to be sent to the server.
  final int pendingCount;

  /// True while a flush pass is in progress.
  final bool isSyncing;

  /// Timestamp of the most recent successfully synced item this session.
  final DateTime? lastSyncedAt;

  SyncStatus copyWith({
    int? pendingCount,
    bool? isSyncing,
    DateTime? lastSyncedAt,
  }) =>
      SyncStatus(
        pendingCount: pendingCount ?? this.pendingCount,
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus(pendingCount: 0, isSyncing: false);

  void setIsSyncing(bool value) {
    state = state.copyWith(isSyncing: value);
  }

  void recordSync() {
    state = state.copyWith(lastSyncedAt: DateTime.now());
  }

  Future<void> refreshCount() async {
    final count = await ref.read(appDatabaseProvider).syncDao.getCount();
    state = state.copyWith(pendingCount: count);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);
