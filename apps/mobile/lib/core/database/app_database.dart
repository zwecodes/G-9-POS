import 'package:drift/drift.dart';

import 'daos/category_dao.dart';
import 'daos/expense_dao.dart';
import 'daos/inventory_event_dao.dart';
import 'daos/product_dao.dart';
import 'daos/sale_dao.dart';
import 'daos/sale_item_dao.dart';
import 'daos/supplier_dao.dart';
import 'daos/supplier_order_dao.dart';
import 'daos/sync_queue_dao.dart';
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
  daos: [
    ProductDao,
    CategoryDao,
    InventoryEventDao,
    SaleDao,
    SaleItemDao,
    ExpenseDao,
    SupplierDao,
    SupplierOrderDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
