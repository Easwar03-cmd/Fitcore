part of '../app_database.dart';

@DriftAccessor(tables: [PendingSyncItems])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Persists a write operation so it can be retried later.
  /// [httpMethod] is 'POST' (default) or 'DELETE'.
  /// For DELETE operations the resource ID must be embedded in [endpoint].
  Future<void> enqueue(
    String endpoint,
    String payloadJson, {
    String httpMethod = 'POST',
  }) =>
      into(pendingSyncItems).insert(
        PendingSyncItemsCompanion.insert(
          endpoint: endpoint,
          payloadJson: payloadJson,
          httpMethod: Value(httpMethod),
        ),
      );

  /// Removes a successfully synced (or permanently failed) item.
  Future<void> deleteById(int id) =>
      (delete(pendingSyncItems)..where((t) => t.id.equals(id))).go();

  /// Updates retry metadata after a failed attempt.
  Future<void> markRetry(int id, DateTime retryAfter, int retryCount) =>
      (update(pendingSyncItems)..where((t) => t.id.equals(id))).write(
        PendingSyncItemsCompanion(
          retryAfter: Value(retryAfter),
          retryCount: Value(retryCount),
        ),
      );

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Items that are due now: retryAfter IS NULL or retryAfter <= now.
  /// Ordered FIFO by createdAt so older operations are replayed first.
  Future<List<PendingSyncItem>> getDueItems() {
    final now = DateTime.now();
    return (select(pendingSyncItems)
          ..where(
            (t) => t.retryAfter.isNull() | t.retryAfter.isSmallerOrEqualValue(now),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// One-shot count of all items still in the queue.
  Future<int> getCount() async {
    final rows = await select(pendingSyncItems).get();
    return rows.length;
  }

  /// Live count of pending items — drives the sync status banner.
  Stream<int> watchCount() =>
      select(pendingSyncItems).watch().map((rows) => rows.length);
}
