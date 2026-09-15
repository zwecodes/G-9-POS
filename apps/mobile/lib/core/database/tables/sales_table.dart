import 'package:drift/drift.dart';

/// SQLite `sales` — DATA-MODEL.md §3.6.
/// No `updated_at` / `deleted_at`. `server_received_at` is server-authored and
/// nullable until `GET /v1/sync/pull` / first-run pull.
@TableIndex(name: 'idx_sales_created_at', columns: {#createdAt})
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get saleNumber => text()();
  TextColumn get operatorId => text()();
  TextColumn get deviceId => text()();
  TextColumn get paymentMethod => text()();
  IntColumn get totalAmountMmk => integer()();
  IntColumn get discountAmountMmk => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  TextColumn get status => text()();
  IntColumn get voidedAt => integer().nullable()();
  TextColumn get voidedBy => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get serverReceivedAt => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
