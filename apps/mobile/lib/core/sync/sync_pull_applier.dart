import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../database/app_database.dart';
import 'sync_pull_payload.dart';

class SyncPullApplier {
  SyncPullApplier({
    required AppDatabase db,
    Logger? logger,
    int Function()? nowMs,
  })  : _db = db,
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs;

  final AppDatabase _db;
  final Logger _log;
  final int Function() _nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> apply(PullPayload payload) {
    return _db.transaction(() async {
      for (final row in payload.categories) {
        await _upsertCategory(row);
      }
      for (final row in payload.products) {
        await _upsertProduct(row);
      }
      for (final row in payload.users) {
        await _upsertUser(row);
      }
      for (final row in payload.suppliers) {
        await _upsertSupplier(row);
      }
      for (final row in payload.inventoryEvents) {
        await _insertInventory(row);
      }
      for (final row in payload.sales) {
        await _upsertSale(row);
      }
      for (final row in payload.saleItems) {
        await _upsertSaleItem(row);
      }
      for (final row in payload.expenses) {
        await _upsertExpense(row);
      }
      for (final row in payload.supplierOrders) {
        await _upsertSupplierOrder(row);
      }
      for (final row in payload.supplierOrderItems) {
        await _upsertSupplierOrderItem(row);
      }
      for (final row in payload.saleServerReceived) {
        await _stampSale(row);
      }
    });
  }

  Future<void> _upsertCategory(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final name = pullString(row['name']);
    final createdAt = pullInt(row['created_at']);
    final updatedAt = pullInt(row['updated_at']);
    final deviceId = pullString(row['device_id']);
    if (id == null ||
        name == null ||
        createdAt == null ||
        updatedAt == null ||
        deviceId == null) {
      _log.w('Skipped category row from pull');
      return;
    }
    if (await _hasPending(id)) return;
    final existing = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (existing != null && existing.updatedAt > updatedAt) return;

    await _db.categoryDao.upsert(
      CategoriesCompanion(
        id: Value(id),
        name: Value(name),
        sortOrder: Value(pullInt(row['sort_order']) ?? 0),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(pullInt(row['deleted_at'])),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> _upsertProduct(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final name = pullString(row['name']);
    final createdAt = pullInt(row['created_at']);
    final updatedAt = pullInt(row['updated_at']);
    final deviceId = pullString(row['device_id']);
    final price = pullInt(row['price_mmk']);
    if (id == null ||
        name == null ||
        createdAt == null ||
        updatedAt == null ||
        deviceId == null ||
        price == null) {
      _log.w('Skipped product row from pull');
      return;
    }
    if (await _hasPending(id)) return;
    final existing = await _db.productDao.getById(id);
    if (existing != null && existing.updatedAt > updatedAt) return;

    await _db.productDao.upsert(
      ProductsCompanion(
        id: Value(id),
        categoryId: Value(pullString(row['category_id'])),
        name: Value(name),
        barcode: Value(pullString(row['barcode'])),
        priceMmk: Value(price),
        costPriceMmk: Value(pullInt(row['cost_price_mmk'])),
        unit: Value(pullString(row['unit']) ?? 'pcs'),
        lowStockThreshold: Value(pullInt(row['low_stock_threshold']) ?? 5),
        imagePath: Value(pullString(row['image_path'])),
        isActive: Value(pullBool(row['is_active']) ?? true),
        stockNegative: Value(pullBool(row['stock_negative']) ?? false),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(pullInt(row['deleted_at'])),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> _upsertUser(Map<String, dynamic> row) async {
    // DATA-MODEL.md §3.1 / API-SPEC.md §2.6 — PIN hashes pull; password never.
    row.remove('password_hash');
    row.remove('password');
    final id = pullString(row['id']);
    final name = pullString(row['name']);
    final pin = pullString(row['pin']);
    final role = pullString(row['role']);
    final createdAt = pullInt(row['created_at']);
    final updatedAt = pullInt(row['updated_at']);
    if (id == null ||
        name == null ||
        pin == null ||
        pin.isEmpty ||
        role == null ||
        createdAt == null ||
        updatedAt == null) {
      _log.w('Skipped user row from pull');
      return;
    }
    final existing = await (_db.select(_db.users)
          ..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    if (existing != null && existing.updatedAt > updatedAt) return;

    await _db.into(_db.users).insertOnConflictUpdate(
          UsersCompanion(
            id: Value(id),
            name: Value(name),
            pin: Value(pin),
            role: Value(role),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
            deletedAt: Value(pullInt(row['deleted_at'])),
          ),
        );
  }

  Future<void> _upsertSupplier(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final name = pullString(row['name']);
    final createdAt = pullInt(row['created_at']);
    final updatedAt = pullInt(row['updated_at']);
    final deviceId = pullString(row['device_id']);
    if (id == null ||
        name == null ||
        createdAt == null ||
        updatedAt == null ||
        deviceId == null) {
      _log.w('Skipped supplier row from pull');
      return;
    }
    if (await _hasPending(id)) return;
    final existing = await (_db.select(_db.suppliers)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    if (existing != null && existing.updatedAt > updatedAt) return;

    await _db.supplierDao.upsert(
      SuppliersCompanion(
        id: Value(id),
        name: Value(name),
        phone: Value(pullString(row['phone'])),
        address: Value(pullString(row['address'])),
        note: Value(pullString(row['note'])),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(pullInt(row['deleted_at'])),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> _insertInventory(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final productId = pullString(row['product_id']);
    final eventType = pullString(row['event_type']);
    final quantityDelta = pullInt(row['quantity_delta']);
    final referenceType = pullString(row['reference_type']);
    final operatorId = pullString(row['operator_id']);
    final deviceId = pullString(row['device_id']);
    final createdAt = pullInt(row['created_at']);
    if (id == null ||
        productId == null ||
        eventType == null ||
        quantityDelta == null ||
        referenceType == null ||
        operatorId == null ||
        deviceId == null ||
        createdAt == null) {
      _log.w('Skipped inventory row from pull');
      return;
    }
    await _db.into(_db.inventoryEvents).insert(
          InventoryEventsCompanion(
            id: Value(id),
            productId: Value(productId),
            eventType: Value(eventType),
            quantityDelta: Value(quantityDelta),
            referenceId: Value(pullString(row['reference_id'])),
            referenceType: Value(referenceType),
            note: Value(pullString(row['note'])),
            operatorId: Value(operatorId),
            deviceId: Value(deviceId),
            createdAt: Value(createdAt),
            syncedAt: Value(_nowMs()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _upsertSale(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final saleNumber = pullString(row['sale_number']);
    final operatorId = pullString(row['operator_id']);
    final deviceId = pullString(row['device_id']);
    final paymentMethod = pullString(row['payment_method']);
    final total = pullInt(row['total_amount_mmk']);
    final status = pullString(row['status']);
    final createdAt = pullInt(row['created_at']);
    if (id == null ||
        saleNumber == null ||
        operatorId == null ||
        deviceId == null ||
        paymentMethod == null ||
        total == null ||
        status == null ||
        createdAt == null) {
      _log.w('Skipped sale row from pull');
      return;
    }
    if (await _hasPending(id)) return;

    await _db.saleDao.upsert(
      SalesCompanion(
        id: Value(id),
        saleNumber: Value(saleNumber),
        operatorId: Value(operatorId),
        deviceId: Value(deviceId),
        paymentMethod: Value(paymentMethod),
        totalAmountMmk: Value(total),
        discountAmountMmk: Value(pullInt(row['discount_amount_mmk']) ?? 0),
        note: Value(pullString(row['note'])),
        status: Value(status),
        voidedAt: Value(pullInt(row['voided_at'])),
        voidedBy: Value(pullString(row['voided_by'])),
        voidReason: Value(pullString(row['void_reason'])),
        createdAt: Value(createdAt),
        serverReceivedAt: Value(pullInt(row['server_received_at'])),
        syncedAt: Value(_nowMs()),
      ),
    );
  }

  Future<void> _upsertSaleItem(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final saleId = pullString(row['sale_id']);
    final productId = pullString(row['product_id']);
    final snapshotName = pullString(row['product_name_snapshot']);
    final price = pullInt(row['price_snapshot_mmk']);
    final quantity = pullInt(row['quantity']);
    final subtotal = pullInt(row['subtotal_mmk']);
    final createdAt = pullInt(row['created_at']);
    if (id == null ||
        saleId == null ||
        productId == null ||
        snapshotName == null ||
        price == null ||
        quantity == null ||
        subtotal == null ||
        createdAt == null) {
      _log.w('Skipped sale item row from pull');
      return;
    }
    await _db.into(_db.saleItems).insert(
          SaleItemsCompanion(
            id: Value(id),
            saleId: Value(saleId),
            productId: Value(productId),
            productNameSnapshot: Value(snapshotName),
            priceSnapshotMmk: Value(price),
            quantity: Value(quantity),
            subtotalMmk: Value(subtotal),
            createdAt: Value(createdAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _upsertExpense(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final category = pullString(row['category']);
    final amount = pullInt(row['amount_mmk']);
    final expenseDate = pullString(row['expense_date']);
    final operatorId = pullString(row['operator_id']);
    final deviceId = pullString(row['device_id']);
    final createdAt = pullInt(row['created_at']);
    final updatedAt = pullInt(row['updated_at']);
    if (id == null ||
        category == null ||
        amount == null ||
        expenseDate == null ||
        operatorId == null ||
        deviceId == null ||
        createdAt == null ||
        updatedAt == null) {
      _log.w('Skipped expense row from pull');
      return;
    }
    if (await _hasPending(id)) return;
    await _db.expenseDao.upsert(
      ExpensesCompanion(
        id: Value(id),
        category: Value(category),
        amountMmk: Value(amount),
        note: Value(pullString(row['note'])),
        expenseDate: Value(expenseDate),
        operatorId: Value(operatorId),
        deviceId: Value(deviceId),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        deletedAt: Value(pullInt(row['deleted_at'])),
        syncedAt: Value(_nowMs()),
      ),
    );
  }

  Future<void> _upsertSupplierOrder(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final orderDate = pullString(row['order_date']);
    final total = pullInt(row['total_cost_mmk']);
    final status = pullString(row['status']);
    final operatorId = pullString(row['operator_id']);
    final deviceId = pullString(row['device_id']);
    final createdAt = pullInt(row['created_at']);
    final updatedAt = pullInt(row['updated_at']);
    if (id == null ||
        orderDate == null ||
        total == null ||
        status == null ||
        operatorId == null ||
        deviceId == null ||
        createdAt == null ||
        updatedAt == null) {
      _log.w('Skipped supplier order row from pull');
      return;
    }
    if (await _hasPending(id)) return;
    await _db.supplierOrderDao.upsert(
      SupplierOrdersCompanion(
        id: Value(id),
        supplierId: Value(pullString(row['supplier_id'])),
        orderDate: Value(orderDate),
        totalCostMmk: Value(total),
        note: Value(pullString(row['note'])),
        status: Value(status),
        receivedAt: Value(pullInt(row['received_at'])),
        operatorId: Value(operatorId),
        deviceId: Value(deviceId),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        syncedAt: Value(_nowMs()),
      ),
    );
  }

  Future<void> _upsertSupplierOrderItem(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final orderId = pullString(row['order_id']);
    final productId = pullString(row['product_id']);
    final quantity = pullInt(row['quantity']);
    final cost = pullInt(row['cost_per_unit_mmk']);
    final subtotal = pullInt(row['subtotal_mmk']);
    final createdAt = pullInt(row['created_at']);
    if (id == null ||
        orderId == null ||
        productId == null ||
        quantity == null ||
        cost == null ||
        subtotal == null ||
        createdAt == null) {
      _log.w('Skipped supplier order item row from pull');
      return;
    }
    await _db.into(_db.supplierOrderItems).insert(
          SupplierOrderItemsCompanion(
            id: Value(id),
            orderId: Value(orderId),
            productId: Value(productId),
            quantity: Value(quantity),
            costPerUnitMmk: Value(cost),
            subtotalMmk: Value(subtotal),
            createdAt: Value(createdAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _stampSale(Map<String, dynamic> row) async {
    final id = pullString(row['id']);
    final stamped = pullInt(row['server_received_at']);
    if (id == null || stamped == null) return;
    await (_db.update(_db.sales)..where((s) => s.id.equals(id))).write(
      SalesCompanion(serverReceivedAt: Value(stamped)),
    );
  }

  Future<bool> _hasPending(String entityId) async {
    final row = await _db.syncQueueDao.getById(entityId);
    return row != null && row.syncedAt == null;
  }
}
