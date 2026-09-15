// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_event_dao.dart';

// ignore_for_file: type=lint
mixin _$InventoryEventDaoMixin on DatabaseAccessor<AppDatabase> {
  $InventoryEventsTable get inventoryEvents => attachedDatabase.inventoryEvents;
  InventoryEventDaoManager get managers => InventoryEventDaoManager(this);
}

class InventoryEventDaoManager {
  final _$InventoryEventDaoMixin _db;
  InventoryEventDaoManager(this._db);
  $$InventoryEventsTableTableManager get inventoryEvents =>
      $$InventoryEventsTableTableManager(
        _db.attachedDatabase,
        _db.inventoryEvents,
      );
}
