import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/inventory_events_table.dart';

part 'inventory_event_dao.g.dart';

@DriftAccessor(tables: [InventoryEvents])
class InventoryEventDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryEventDaoMixin {
  InventoryEventDao(super.db);

  Future<void> insertEvent(InventoryEventsCompanion event) =>
      into(inventoryEvents).insert(event);

  Future<InventoryEvent?> getById(String id) =>
      (select(inventoryEvents)..where((e) => e.id.equals(id)))
          .getSingleOrNull();

  Future<List<InventoryEvent>> getByReferenceId(String referenceId) =>
      (select(inventoryEvents)
            ..where((e) => e.referenceId.equals(referenceId)))
          .get();

  Stream<List<InventoryEvent>> watchByProductId(String productId) =>
      (select(inventoryEvents)..where((e) => e.productId.equals(productId)))
          .watch();

  /// Device stock: `SUM(quantity_delta)` excluding locally rejected rows.
  /// DATA-MODEL.md §3.5 / G1 — never omit `rejectedAt.isNull()`.
  Future<int> computeStock(String productId) async {
    final delta = inventoryEvents.quantityDelta.sum();
    final query = selectOnly(inventoryEvents)
      ..addColumns([delta])
      ..where(
        inventoryEvents.productId.equals(productId) &
            inventoryEvents.rejectedAt.isNull(),
      );
    return (await query.getSingle()).read(delta) ?? 0;
  }

  /// Standalone rejection: mark by event `id` while `synced_at IS NULL`.
  Future<void> markRejected(String eventId, int now) =>
      (update(inventoryEvents)
            ..where((e) => e.id.equals(eventId) & e.syncedAt.isNull()))
          .write(InventoryEventsCompanion(rejectedAt: Value(now)));

  /// Grouped rejection: mark by `reference_id` while `synced_at IS NULL`.
  Future<void> markGroupRejected(String referenceId, int now) =>
      (update(inventoryEvents)..where(
            (e) => e.referenceId.equals(referenceId) & e.syncedAt.isNull(),
          ))
          .write(InventoryEventsCompanion(rejectedAt: Value(now)));
}
