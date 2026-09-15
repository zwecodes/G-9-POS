// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_item_dao.dart';

// ignore_for_file: type=lint
mixin _$SaleItemDaoMixin on DatabaseAccessor<AppDatabase> {
  $SaleItemsTable get saleItems => attachedDatabase.saleItems;
  SaleItemDaoManager get managers => SaleItemDaoManager(this);
}

class SaleItemDaoManager {
  final _$SaleItemDaoMixin _db;
  SaleItemDaoManager(this._db);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db.attachedDatabase, _db.saleItems);
}
