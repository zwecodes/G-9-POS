import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/supplier_orders_table.dart';

part 'supplier_order_dao.g.dart';

@DriftAccessor(tables: [SupplierOrders])
class SupplierOrderDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierOrderDaoMixin {
  SupplierOrderDao(super.db);

  Stream<List<SupplierOrder>> watchAll() => (select(supplierOrders)
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
      .watch();

  Future<List<SupplierOrder>> getAll() => (select(supplierOrders)
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
      .get();

  Future<SupplierOrder?> getById(String id) =>
      (select(supplierOrders)..where((o) => o.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsert(SupplierOrdersCompanion order) =>
      into(supplierOrders).insertOnConflictUpdate(order);
}
