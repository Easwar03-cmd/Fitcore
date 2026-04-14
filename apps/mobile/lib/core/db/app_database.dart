import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';
part 'daos/sync_dao.dart';

// ── Table ─────────────────────────────────────────────────────────────────────

/// Stores write operations that failed due to a network error.
/// Flushed in insertion order on app resume / connectivity restore.
/// Supports POST and DELETE operations with exponential-backoff retry.
class PendingSyncItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// API path relative to /api/v1, e.g. '/nutrition/food-logs'.
  /// For DELETE operations the resource ID is embedded in the path.
  TextColumn get endpoint => text()();

  /// JSON-encoded request body — empty map '{}' for DELETE operations.
  TextColumn get payloadJson => text()();

  /// HTTP verb: 'POST' or 'DELETE'.
  TextColumn get httpMethod =>
      text().withDefault(const Constant('POST'))();

  /// Number of times this item has been attempted and failed.
  /// 0 = not yet attempted, 1–4 = awaiting retry, >4 = permanently failed.
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0))();

  /// Earliest DateTime at which this item may next be retried.
  /// NULL means the item is immediately due (just enqueued or never tried).
  DateTimeColumn get retryAfter => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [PendingSyncItems], daos: [SyncDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'fitcore'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: add httpMethod, retryCount, retryAfter columns.
            // Raw SQL avoids GeneratedColumn<T> type-variance issues in Dart.
            await m.issueCustomQuery(
              "ALTER TABLE pending_sync_items "
              "ADD COLUMN http_method TEXT NOT NULL DEFAULT 'POST'",
            );
            await m.issueCustomQuery(
              'ALTER TABLE pending_sync_items '
              'ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
            );
            // Drift stores DateTimeColumn as INTEGER (Unix ms). NULL = immediately due.
            await m.issueCustomQuery(
              'ALTER TABLE pending_sync_items '
              'ADD COLUMN retry_after INTEGER',
            );
          }
        },
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
