import 'package:drift/drift.dart';

/// SQLite `inventory_events` — DATA-MODEL.md §3.5.
/// Append-only. No `updated_at` / `deleted_at`. No `server_received_at` (PostgreSQL only).
/// G1: `rejected_at` is local-only and settable only while `synced_at IS NULL`.
@TableIndex(name: 'idx_inventory_events_product_id', columns: {#productId})
@TableIndex.sql(
  'CREATE INDEX idx_inventory_events_product_stock ON inventory_events (product_id) WHERE rejected_at IS NULL',
)
class InventoryEvents extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get eventType => text()();
  IntColumn get quantityDelta => integer()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get referenceType => text()();
  TextColumn get note => text().nullable()();
  TextColumn get operatorId => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get syncedAt => integer().nullable()();
  IntColumn get rejectedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        // rejected_at IS NOT NULL → synced_at IS NULL (DATA-MODEL.md §3.5, G1)
        'CHECK (rejected_at IS NULL OR synced_at IS NULL)',
      ];
}
