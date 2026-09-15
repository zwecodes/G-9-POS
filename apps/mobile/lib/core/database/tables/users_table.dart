import 'package:drift/drift.dart';

/// SQLite `users` — DATA-MODEL.md §3.1.
/// No `username` / `password_hash` (PostgreSQL only). No `device_id`.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get pin => text()();
  TextColumn get role => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
