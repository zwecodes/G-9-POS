import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/products_table.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  Stream<List<Product>> watchAllActive() =>
      (select(products)..where((p) => p.deletedAt.isNull())).watch();

  Future<List<Product>> getAllActive() =>
      (select(products)..where((p) => p.deletedAt.isNull())).get();

  Future<Product?> getById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Product?> getActiveById(String id) =>
      (select(products)
            ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .getSingleOrNull();

  Future<Product?> getByBarcode(String barcode) =>
      (select(products)
            ..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull()))
          .getSingleOrNull();

  Future<int> countActiveByCategory(String categoryId) async {
    final countExp = products.id.count();
    final query = selectOnly(products)
      ..addColumns([countExp])
      ..where(products.categoryId.equals(categoryId) & products.deletedAt.isNull());
    return (await query.getSingle()).read(countExp) ?? 0;
  }

  Future<void> upsert(ProductsCompanion product) =>
      into(products).insertOnConflictUpdate(product);

  Future<void> softDelete(String id, int deletedAt) =>
      (update(products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(deletedAt: Value(deletedAt)),
      );
}
