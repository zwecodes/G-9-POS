import 'package:drift/drift.dart';

/// SQLite `supplier_orders` — DATA-MODEL.md §3.10.
/// No `deleted_at` in §3.10.
class SupplierOrders extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().nullable()();
  TextColumn get orderDate => text()();
  IntColumn get totalCostMmk => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text()();
  IntColumn get receivedAt => integer().nullable()();
  TextColumn get operatorId => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get syncedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
