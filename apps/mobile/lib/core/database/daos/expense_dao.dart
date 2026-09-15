import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/expenses_table.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  Stream<List<Expense>> watchAllActive() =>
      (select(expenses)..where((e) => e.deletedAt.isNull())).watch();

  Future<List<Expense>> getAllActive() =>
      (select(expenses)..where((e) => e.deletedAt.isNull())).get();

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
