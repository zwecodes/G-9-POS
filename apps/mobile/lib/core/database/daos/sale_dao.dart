import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sales_table.dart';

part 'sale_dao.g.dart';

@DriftAccessor(tables: [Sales])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  Stream<List<Sale>> watchAll() => (select(sales)
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .watch();

  Future<List<Sale>> getAll() => (select(sales)
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();

  Future<Sale?> getById(String id) =>
      (select(sales)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> upsert(SalesCompanion sale) =>
      into(sales).insertOnConflictUpdate(sale);
}
