// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PendingSyncItemsTable extends PendingSyncItems
    with TableInfo<$PendingSyncItemsTable, PendingSyncItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _endpointMeta =
      const VerificationMeta('endpoint');
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
      'endpoint', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _httpMethodMeta =
      const VerificationMeta('httpMethod');
  @override
  late final GeneratedColumn<String> httpMethod = GeneratedColumn<String>(
      'http_method', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('POST'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _retryAfterMeta =
      const VerificationMeta('retryAfter');
  @override
  late final GeneratedColumn<DateTime> retryAfter = GeneratedColumn<DateTime>(
      'retry_after', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        endpoint,
        payloadJson,
        httpMethod,
        retryCount,
        retryAfter,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sync_items';
  @override
  VerificationContext validateIntegrity(Insertable<PendingSyncItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('endpoint')) {
      context.handle(_endpointMeta,
          endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta));
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('http_method')) {
      context.handle(
          _httpMethodMeta,
          httpMethod.isAcceptableOrUnknown(
              data['http_method']!, _httpMethodMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('retry_after')) {
      context.handle(
          _retryAfterMeta,
          retryAfter.isAcceptableOrUnknown(
              data['retry_after']!, _retryAfterMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSyncItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSyncItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      endpoint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}endpoint'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      httpMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}http_method'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      retryAfter: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}retry_after']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PendingSyncItemsTable createAlias(String alias) {
    return $PendingSyncItemsTable(attachedDatabase, alias);
  }
}

class PendingSyncItem extends DataClass implements Insertable<PendingSyncItem> {
  final int id;

  /// API path relative to /api/v1, e.g. '/nutrition/food-logs'.
  /// For DELETE operations the resource ID is embedded in the path.
  final String endpoint;

  /// JSON-encoded request body — empty map '{}' for DELETE operations.
  final String payloadJson;

  /// HTTP verb: 'POST' or 'DELETE'.
  final String httpMethod;

  /// Number of times this item has been attempted and failed.
  /// 0 = not yet attempted, 1–4 = awaiting retry, >4 = permanently failed.
  final int retryCount;

  /// Earliest DateTime at which this item may next be retried.
  /// NULL means the item is immediately due (just enqueued or never tried).
  final DateTime? retryAfter;
  final DateTime createdAt;
  const PendingSyncItem(
      {required this.id,
      required this.endpoint,
      required this.payloadJson,
      required this.httpMethod,
      required this.retryCount,
      this.retryAfter,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['endpoint'] = Variable<String>(endpoint);
    map['payload_json'] = Variable<String>(payloadJson);
    map['http_method'] = Variable<String>(httpMethod);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || retryAfter != null) {
      map['retry_after'] = Variable<DateTime>(retryAfter);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingSyncItemsCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncItemsCompanion(
      id: Value(id),
      endpoint: Value(endpoint),
      payloadJson: Value(payloadJson),
      httpMethod: Value(httpMethod),
      retryCount: Value(retryCount),
      retryAfter: retryAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(retryAfter),
      createdAt: Value(createdAt),
    );
  }

  factory PendingSyncItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSyncItem(
      id: serializer.fromJson<int>(json['id']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      httpMethod: serializer.fromJson<String>(json['httpMethod']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      retryAfter: serializer.fromJson<DateTime?>(json['retryAfter']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'endpoint': serializer.toJson<String>(endpoint),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'httpMethod': serializer.toJson<String>(httpMethod),
      'retryCount': serializer.toJson<int>(retryCount),
      'retryAfter': serializer.toJson<DateTime?>(retryAfter),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingSyncItem copyWith(
          {int? id,
          String? endpoint,
          String? payloadJson,
          String? httpMethod,
          int? retryCount,
          Value<DateTime?> retryAfter = const Value.absent(),
          DateTime? createdAt}) =>
      PendingSyncItem(
        id: id ?? this.id,
        endpoint: endpoint ?? this.endpoint,
        payloadJson: payloadJson ?? this.payloadJson,
        httpMethod: httpMethod ?? this.httpMethod,
        retryCount: retryCount ?? this.retryCount,
        retryAfter: retryAfter.present ? retryAfter.value : this.retryAfter,
        createdAt: createdAt ?? this.createdAt,
      );
  PendingSyncItem copyWithCompanion(PendingSyncItemsCompanion data) {
    return PendingSyncItem(
      id: data.id.present ? data.id.value : this.id,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      httpMethod:
          data.httpMethod.present ? data.httpMethod.value : this.httpMethod,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      retryAfter:
          data.retryAfter.present ? data.retryAfter.value : this.retryAfter,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncItem(')
          ..write('id: $id, ')
          ..write('endpoint: $endpoint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('httpMethod: $httpMethod, ')
          ..write('retryCount: $retryCount, ')
          ..write('retryAfter: $retryAfter, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, endpoint, payloadJson, httpMethod, retryCount, retryAfter, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSyncItem &&
          other.id == this.id &&
          other.endpoint == this.endpoint &&
          other.payloadJson == this.payloadJson &&
          other.httpMethod == this.httpMethod &&
          other.retryCount == this.retryCount &&
          other.retryAfter == this.retryAfter &&
          other.createdAt == this.createdAt);
}

class PendingSyncItemsCompanion extends UpdateCompanion<PendingSyncItem> {
  final Value<int> id;
  final Value<String> endpoint;
  final Value<String> payloadJson;
  final Value<String> httpMethod;
  final Value<int> retryCount;
  final Value<DateTime?> retryAfter;
  final Value<DateTime> createdAt;
  const PendingSyncItemsCompanion({
    this.id = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.httpMethod = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.retryAfter = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingSyncItemsCompanion.insert({
    this.id = const Value.absent(),
    required String endpoint,
    required String payloadJson,
    this.httpMethod = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.retryAfter = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : endpoint = Value(endpoint),
        payloadJson = Value(payloadJson);
  static Insertable<PendingSyncItem> custom({
    Expression<int>? id,
    Expression<String>? endpoint,
    Expression<String>? payloadJson,
    Expression<String>? httpMethod,
    Expression<int>? retryCount,
    Expression<DateTime>? retryAfter,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (endpoint != null) 'endpoint': endpoint,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (httpMethod != null) 'http_method': httpMethod,
      if (retryCount != null) 'retry_count': retryCount,
      if (retryAfter != null) 'retry_after': retryAfter,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingSyncItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? endpoint,
      Value<String>? payloadJson,
      Value<String>? httpMethod,
      Value<int>? retryCount,
      Value<DateTime?>? retryAfter,
      Value<DateTime>? createdAt}) {
    return PendingSyncItemsCompanion(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      payloadJson: payloadJson ?? this.payloadJson,
      httpMethod: httpMethod ?? this.httpMethod,
      retryCount: retryCount ?? this.retryCount,
      retryAfter: retryAfter ?? this.retryAfter,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (httpMethod.present) {
      map['http_method'] = Variable<String>(httpMethod.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (retryAfter.present) {
      map['retry_after'] = Variable<DateTime>(retryAfter.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncItemsCompanion(')
          ..write('id: $id, ')
          ..write('endpoint: $endpoint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('httpMethod: $httpMethod, ')
          ..write('retryCount: $retryCount, ')
          ..write('retryAfter: $retryAfter, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PendingSyncItemsTable pendingSyncItems =
      $PendingSyncItemsTable(this);
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pendingSyncItems];
}

typedef $$PendingSyncItemsTableCreateCompanionBuilder
    = PendingSyncItemsCompanion Function({
  Value<int> id,
  required String endpoint,
  required String payloadJson,
  Value<String> httpMethod,
  Value<int> retryCount,
  Value<DateTime?> retryAfter,
  Value<DateTime> createdAt,
});
typedef $$PendingSyncItemsTableUpdateCompanionBuilder
    = PendingSyncItemsCompanion Function({
  Value<int> id,
  Value<String> endpoint,
  Value<String> payloadJson,
  Value<String> httpMethod,
  Value<int> retryCount,
  Value<DateTime?> retryAfter,
  Value<DateTime> createdAt,
});

class $$PendingSyncItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSyncItemsTable> {
  $$PendingSyncItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get httpMethod => $composableBuilder(
      column: $table.httpMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get retryAfter => $composableBuilder(
      column: $table.retryAfter, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingSyncItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSyncItemsTable> {
  $$PendingSyncItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get httpMethod => $composableBuilder(
      column: $table.httpMethod, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get retryAfter => $composableBuilder(
      column: $table.retryAfter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingSyncItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSyncItemsTable> {
  $$PendingSyncItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get httpMethod => $composableBuilder(
      column: $table.httpMethod, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get retryAfter => $composableBuilder(
      column: $table.retryAfter, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingSyncItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingSyncItemsTable,
    PendingSyncItem,
    $$PendingSyncItemsTableFilterComposer,
    $$PendingSyncItemsTableOrderingComposer,
    $$PendingSyncItemsTableAnnotationComposer,
    $$PendingSyncItemsTableCreateCompanionBuilder,
    $$PendingSyncItemsTableUpdateCompanionBuilder,
    (
      PendingSyncItem,
      BaseReferences<_$AppDatabase, $PendingSyncItemsTable, PendingSyncItem>
    ),
    PendingSyncItem,
    PrefetchHooks Function()> {
  $$PendingSyncItemsTableTableManager(
      _$AppDatabase db, $PendingSyncItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSyncItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSyncItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSyncItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> endpoint = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String> httpMethod = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime?> retryAfter = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PendingSyncItemsCompanion(
            id: id,
            endpoint: endpoint,
            payloadJson: payloadJson,
            httpMethod: httpMethod,
            retryCount: retryCount,
            retryAfter: retryAfter,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String endpoint,
            required String payloadJson,
            Value<String> httpMethod = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime?> retryAfter = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              PendingSyncItemsCompanion.insert(
            id: id,
            endpoint: endpoint,
            payloadJson: payloadJson,
            httpMethod: httpMethod,
            retryCount: retryCount,
            retryAfter: retryAfter,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingSyncItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingSyncItemsTable,
    PendingSyncItem,
    $$PendingSyncItemsTableFilterComposer,
    $$PendingSyncItemsTableOrderingComposer,
    $$PendingSyncItemsTableAnnotationComposer,
    $$PendingSyncItemsTableCreateCompanionBuilder,
    $$PendingSyncItemsTableUpdateCompanionBuilder,
    (
      PendingSyncItem,
      BaseReferences<_$AppDatabase, $PendingSyncItemsTable, PendingSyncItem>
    ),
    PendingSyncItem,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingSyncItemsTableTableManager get pendingSyncItems =>
      $$PendingSyncItemsTableTableManager(_db, _db.pendingSyncItems);
}

mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingSyncItemsTable get pendingSyncItems =>
      attachedDatabase.pendingSyncItems;
}
