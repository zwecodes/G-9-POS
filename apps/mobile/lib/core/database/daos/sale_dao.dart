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

  Future<void> markSynced(String id, int syncedAt) =>
      (update(sales)..where((s) => s.id.equals(id))).write(
        SalesCompanion(syncedAt: Value(syncedAt)),
      );

  /// SYNC-PROTOCOL.md §4.4 / §11.2 — restore a locally voided sale.
  Future<void> restoreCompleted(String id) =>
      (update(sales)..where((s) => s.id.equals(id))).write(
        const SalesCompanion(
          status: Value('completed'),
          voidedAt: Value(null),
          voidedBy: Value(null),
          voidReason: Value(null),
        ),
      );
}
