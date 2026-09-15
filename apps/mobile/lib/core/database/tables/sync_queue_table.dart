import 'package:drift/drift.dart';

/// SQLite-only `sync_queue` — DATA-MODEL.md §3.12.
/// `reference_id` is the causal-group key; NULL for standalone events.
@TableIndex(name: 'idx_sync_queue_synced_at', columns: {#syncedAt})
@TableIndex(name: 'idx_sync_queue_reference_id', columns: {#referenceId})
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  TextColumn get payload => text()();
  TextColumn get deviceId => text()();
  TextColumn get referenceId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get syncedAt => integer().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
