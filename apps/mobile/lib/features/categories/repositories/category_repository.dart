import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

class CategoryRepository {
  CategoryRepository({
    required AppDatabase db,
    required AppIdentity identity,
    UuidGenerator? uuids,
    Logger? logger,
    int Function()? nowMs,
  })  : _db = db,
        _identity = identity,
        _uuids = uuids ?? UuidGenerator(),
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs;

  final AppDatabase _db;
  final AppIdentity _identity;
  final UuidGenerator _uuids;
  final Logger _log;
  final int Function() _nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Stream<List<Category>> watchAll() => _db.categoryDao.watchAllActive();

  Future<List<Category>> getAll() => _db.categoryDao.getAllActive();

  Future<Category?> getById(String id) => _db.categoryDao.getById(id);

  Future<Category> create({
    required String name,
    int sortOrder = 0,
  }) {
    return runRepositoryWrite(
      _log,
      'Could not create category',
      'Could not save the category. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final trimmed = name.trim();
        if (trimmed.isEmpty) {
          throw const RepositoryException('Please enter a category name.');
        }
        final id = _uuids.v4();
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await _db.transaction(() async {
          await _db.categoryDao.upsert(
            CategoriesCompanion.insert(
              id: id,
              name: trimmed,
              sortOrder: sortOrder,
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
          );
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: SyncEventType.categoryCreated,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            extra: {'name': trimmed, 'sort_order': sortOrder},
          );
        });
        return (await _db.categoryDao.getById(id))!;
      },
    );
  }

  Future<void> update({
    required String id,
    required String name,
    required int sortOrder,
  }) {
    return runRepositoryWrite(
      _log,
      'Could not update category',
      'Could not save the category. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final trimmed = name.trim();
        if (trimmed.isEmpty) {
          throw const RepositoryException('Please enter a category name.');
        }
        final existing = await _db.categoryDao.getById(id);
        if (existing == null) {
          throw const RepositoryException('That category is no longer available.');
        }
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await _db.transaction(() async {
          await _db.categoryDao.upsert(
            CategoriesCompanion(
              id: Value(id),
              name: Value(trimmed),
              sortOrder: Value(sortOrder),
              createdAt: Value(existing.createdAt),
              updatedAt: Value(now),
              deviceId: Value(deviceId),
            ),
          );
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: SyncEventType.categoryUpdated,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            extra: {'name': trimmed, 'sort_order': sortOrder},
          );
        });
      },
    );
  }

  Future<void> delete(String id) {
    return runRepositoryWrite(
      _log,
      'Could not delete category',
      'Could not delete the category. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final existing = await _db.categoryDao.getById(id);
        if (existing == null) {
          throw const RepositoryException('That category is no longer available.');
        }
        final blocking = await _db.productDao.countActiveByCategory(id);
        if (blocking > 0) {
          throw RepositoryException(
            'This category still has products. Move them first.',
            code: 'CATEGORY_HAS_PRODUCTS',
          );
        }
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await _db.transaction(() async {
          await _db.categoryDao.softDelete(id, now);
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: SyncEventType.categoryDeleted,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
          );
        });
      },
    );
  }
}
