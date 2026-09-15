// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_order_dao.dart';

// ignore_for_file: type=lint
mixin _$SupplierOrderDaoMixin on DatabaseAccessor<AppDatabase> {
  $SupplierOrdersTable get supplierOrders => attachedDatabase.supplierOrders;
  SupplierOrderDaoManager get managers => SupplierOrderDaoManager(this);
}

class SupplierOrderDaoManager {
  final _$SupplierOrderDaoMixin _db;
  SupplierOrderDaoManager(this._db);
  $$SupplierOrdersTableTableManager get supplierOrders =>
      $$SupplierOrdersTableTableManager(
        _db.attachedDatabase,
        _db.supplierOrders,
      );
}
