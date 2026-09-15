import 'package:drift/drift.dart';

/// SQLite `sale_items` — DATA-MODEL.md §3.7.
/// Nested payload child: no `updated_at`, `deleted_at`, or `device_id`.
@TableIndex(name: 'idx_sale_items_sale_id', columns: {#saleId})
class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get productId => text()();
  TextColumn get productNameSnapshot => text()();
  IntColumn get priceSnapshotMmk => integer()();
  IntColumn get quantity => integer()();
  IntColumn get subtotalMmk => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
