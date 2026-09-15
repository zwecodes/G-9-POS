import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue({
    required String id,
    required String eventType,
    required String payload,
    required String deviceId,
    String? referenceId,
    required int createdAt,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        id: id,
        eventType: eventType,
        payload: payload,
        deviceId: deviceId,
        referenceId: Value(referenceId),
        createdAt: createdAt,
      ),
    );
  }

  Future<List<SyncQueueData>> getPending() =>
      (select(syncQueue)
            ..where((t) => t.syncedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<SyncQueueData?> getById(String id) =>
      (select(syncQueue)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<SyncQueueData>> getByReferenceId(String referenceId) =>
      (select(syncQueue)..where((t) => t.referenceId.equals(referenceId)))
          .get();

  Future<void> markSynced(String id, int syncedAt) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(syncedAt: Value(syncedAt)),
      );

  Future<int> deleteGroup(String referenceId) =>
      (delete(syncQueue)..where((t) => t.referenceId.equals(referenceId))).go();

  Future<int> deleteById(String id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();
}
