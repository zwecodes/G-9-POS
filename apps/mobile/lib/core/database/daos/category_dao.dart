import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchAllActive() =>
      (select(categories)..where((c) => c.deletedAt.isNull())).watch();

  Future<List<Category>> getAllActive() =>
      (select(categories)..where((c) => c.deletedAt.isNull())).get();

  Future<Category?> getById(String id) =>
      (select(categories)
            ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> upsert(CategoriesCompanion category) =>
      into(categories).insertOnConflictUpdate(category);

  Future<void> softDelete(String id, int deletedAt) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(deletedAt: Value(deletedAt)),
      );
}
