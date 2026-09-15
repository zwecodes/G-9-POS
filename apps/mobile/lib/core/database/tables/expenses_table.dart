import 'package:drift/drift.dart';

/// SQLite `expenses` — DATA-MODEL.md §3.8.
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  IntColumn get amountMmk => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get expenseDate => text()();
  TextColumn get operatorId => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
