import 'package:drift/drift.dart';

import 'tables/categories_table.dart';
import 'tables/expenses_table.dart';
import 'tables/inventory_events_table.dart';
import 'tables/products_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/sales_table.dart';
import 'tables/supplier_order_items_table.dart';
import 'tables/supplier_orders_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Categories,
    Products,
    InventoryEvents,
    Sales,
    SaleItems,
    Expenses,
    Suppliers,
    SupplierOrders,
    SupplierOrderItems,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
