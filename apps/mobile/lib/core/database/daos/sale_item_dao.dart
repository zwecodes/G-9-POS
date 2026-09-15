import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sale_items_table.dart';

part 'sale_item_dao.g.dart';

@DriftAccessor(tables: [SaleItems])
class SaleItemDao extends DatabaseAccessor<AppDatabase>
    with _$SaleItemDaoMixin {
  SaleItemDao(super.db);

  Future<List<SaleItem>> getBySaleId(String saleId) =>
      (select(saleItems)..where((i) => i.saleId.equals(saleId))).get();

  Stream<List<SaleItem>> watchBySaleId(String saleId) =>
      (select(saleItems)..where((i) => i.saleId.equals(saleId))).watch();

  Future<void> insertItem(SaleItemsCompanion item) =>
      into(saleItems).insert(item);

  Future<void> insertAll(List<SaleItemsCompanion> items) =>
      batch((b) => b.insertAll(saleItems, items));
}
