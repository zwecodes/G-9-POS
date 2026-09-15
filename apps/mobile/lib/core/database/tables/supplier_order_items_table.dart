import 'package:drift/drift.dart';

/// SQLite `supplier_order_items` — DATA-MODEL.md §3.11.
/// Nested payload child: no `updated_at`, `deleted_at`, or `device_id`.
class SupplierOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  IntColumn get costPerUnitMmk => integer()();
  IntColumn get subtotalMmk => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
