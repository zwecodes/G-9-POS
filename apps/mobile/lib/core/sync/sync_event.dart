/// Wire `event_type` values.
/// API-SPEC.md §5 / SYNC-PROTOCOL.md §3.2 / 30-sync.mdc.
abstract final class SyncEventType {
  static const productCreated = 'PRODUCT_CREATED';
  static const productUpdated = 'PRODUCT_UPDATED';
  static const productDeleted = 'PRODUCT_DELETED';

  static const categoryCreated = 'CATEGORY_CREATED';
  static const categoryUpdated = 'CATEGORY_UPDATED';
  static const categoryDeleted = 'CATEGORY_DELETED';

  static const inventorySold = 'INVENTORY_SOLD';
  static const inventoryVoided = 'INVENTORY_VOIDED';
  static const inventoryRestocked = 'INVENTORY_RESTOCKED';
  static const inventoryAdjusted = 'INVENTORY_ADJUSTED';
  static const inventoryDamaged = 'INVENTORY_DAMAGED';
  static const inventoryReturned = 'INVENTORY_RETURNED';

  static const saleCreated = 'SALE_CREATED';
  static const expenseCreated = 'EXPENSE_CREATED';
  static const expenseUpdated = 'EXPENSE_UPDATED';
  static const expenseDeleted = 'EXPENSE_DELETED';

  static const supplierOrderReceived = 'SUPPLIER_ORDER_RECEIVED';
  static const deviceActivated = 'DEVICE_ACTIVATED';
}
