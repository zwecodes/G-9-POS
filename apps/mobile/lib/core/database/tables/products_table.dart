import 'package:drift/drift.dart';

/// SQLite `products` — DATA-MODEL.md §3.4.
/// Stock is never stored here; it is `SUM(quantity_delta)` from `inventory_events`.
@TableIndex(name: 'idx_products_barcode', columns: {#barcode})
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get priceMmk => integer()();
  IntColumn get costPriceMmk => integer().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get stockNegative => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
