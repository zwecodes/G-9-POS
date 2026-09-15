import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/suppliers_table.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAllActive() =>
      (select(suppliers)..where((s) => s.deletedAt.isNull())).watch();

  Future<List<Supplier>> getAllActive() =>
      (select(suppliers)..where((s) => s.deletedAt.isNull())).get();

  Future<Supplier?> getById(String id) =>
      (select(suppliers)
            ..where((s) => s.id.equals(id) & s.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> upsert(SuppliersCompanion supplier) =>
      into(suppliers).insertOnConflictUpdate(supplier);

  Future<void> softDelete(String id, int deletedAt) =>
      (update(suppliers)..where((s) => s.id.equals(id))).write(
        SuppliersCompanion(deletedAt: Value(deletedAt)),
      );
}
