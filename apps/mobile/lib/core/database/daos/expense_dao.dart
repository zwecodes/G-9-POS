import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/expenses_table.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  Stream<List<Expense>> watchAllActive() {
    return (select(expenses)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([
            (e) => OrderingTerm.desc(e.expenseDate),
            (e) => OrderingTerm.desc(e.createdAt),
          ]))
        .watch();
  }

  Future<List<Expense>> getAllActive() {
    return (select(expenses)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([
            (e) => OrderingTerm.desc(e.expenseDate),
            (e) => OrderingTerm.desc(e.createdAt),
          ]))
        .get();
  }

  Future<Expense?> getById(String id) =>
      (select(expenses)
            ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> upsert(ExpensesCompanion expense) =>
      into(expenses).insertOnConflictUpdate(expense);

  Future<void> softDelete(String id, int deletedAt) =>
      (update(expenses)..where((e) => e.id.equals(id))).write(
        ExpensesCompanion(deletedAt: Value(deletedAt)),
      );
}
