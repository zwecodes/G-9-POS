import 'dart:convert';

const int kSyncPullPageSize = 200;

class PullPayload {
  const PullPayload({
    required this.users,
    required this.categories,
    required this.products,
    required this.suppliers,
    required this.inventoryEvents,
    required this.sales,
    required this.saleItems,
    required this.expenses,
    required this.supplierOrders,
    required this.supplierOrderItems,
    required this.saleServerReceived,
  });

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> inventoryEvents;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> saleItems;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> supplierOrders;
  final List<Map<String, dynamic>> supplierOrderItems;
  final List<Map<String, dynamic>> saleServerReceived;

  bool get hitPageLimit =>
      users.length >= kSyncPullPageSize ||
      categories.length >= kSyncPullPageSize ||
      products.length >= kSyncPullPageSize ||
      suppliers.length >= kSyncPullPageSize ||
      inventoryEvents.length >= kSyncPullPageSize ||
      sales.length >= kSyncPullPageSize ||
      saleItems.length >= kSyncPullPageSize ||
      expenses.length >= kSyncPullPageSize ||
      supplierOrders.length >= kSyncPullPageSize ||
      supplierOrderItems.length >= kSyncPullPageSize ||
      saleServerReceived.length >= kSyncPullPageSize;

  bool get isEmpty =>
      users.isEmpty &&
      categories.isEmpty &&
      products.isEmpty &&
      suppliers.isEmpty &&
      inventoryEvents.isEmpty &&
      sales.isEmpty &&
      saleItems.isEmpty &&
      expenses.isEmpty &&
      supplierOrders.isEmpty &&
      supplierOrderItems.isEmpty &&
      saleServerReceived.isEmpty;

  int? get maxTimestamp {
    final values = <int>[
      ..._maxOf(users, const ['updated_at', 'created_at']),
      ..._maxOf(categories, const ['updated_at', 'created_at']),
      ..._maxOf(products, const ['updated_at', 'created_at']),
      ..._maxOf(suppliers, const ['updated_at', 'created_at']),
      ..._maxOf(inventoryEvents, const ['created_at', 'server_received_at']),
      ..._maxOf(sales, const ['created_at', 'server_received_at']),
      ..._maxOf(saleItems, const ['created_at']),
      ..._maxOf(expenses, const ['updated_at', 'created_at']),
      ..._maxOf(supplierOrders, const ['updated_at', 'created_at']),
      ..._maxOf(supplierOrderItems, const ['created_at']),
      ..._maxOf(saleServerReceived, const ['server_received_at']),
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  int? get pagingWatermark {
    final hitting = <int>[
      if (users.length >= kSyncPullPageSize)
        ..._maxOf(users, const ['updated_at', 'created_at']),
      if (categories.length >= kSyncPullPageSize)
        ..._maxOf(categories, const ['updated_at', 'created_at']),
      if (products.length >= kSyncPullPageSize)
        ..._maxOf(products, const ['updated_at', 'created_at']),
      if (suppliers.length >= kSyncPullPageSize)
        ..._maxOf(suppliers, const ['updated_at', 'created_at']),
      if (inventoryEvents.length >= kSyncPullPageSize)
        ..._maxOf(inventoryEvents, const ['created_at', 'server_received_at']),
      if (sales.length >= kSyncPullPageSize)
        ..._maxOf(sales, const ['created_at', 'server_received_at']),
      if (saleItems.length >= kSyncPullPageSize)
        ..._maxOf(saleItems, const ['created_at']),
      if (expenses.length >= kSyncPullPageSize)
        ..._maxOf(expenses, const ['updated_at', 'created_at']),
      if (supplierOrders.length >= kSyncPullPageSize)
        ..._maxOf(supplierOrders, const ['updated_at', 'created_at']),
      if (supplierOrderItems.length >= kSyncPullPageSize)
        ..._maxOf(supplierOrderItems, const ['created_at']),
      if (saleServerReceived.length >= kSyncPullPageSize)
        ..._maxOf(saleServerReceived, const ['server_received_at']),
    ];
    if (hitting.isEmpty) return null;
    return hitting.reduce((a, b) => a < b ? a : b);
  }

  List<int> _maxOf(List<Map<String, dynamic>> rows, List<String> keys) {
    var max = 0;
    var found = false;
    for (final row in rows) {
      for (final key in keys) {
        final value = pullInt(row[key]);
        if (value != null && value > max) {
          max = value;
          found = true;
        }
      }
    }
    return found ? [max] : const [];
  }
}

PullPayload parsePullPayload(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map) {
    throw const FormatException('Sync pull response was not an object');
  }
  final map = Map<String, dynamic>.from(decoded);
  if (map['error'] is Map) {
    final error = Map<String, dynamic>.from(map['error'] as Map);
    throw FormatException(
      error['message'] as String? ?? 'Could not load updates',
    );
  }
  final dataRaw = map['data'];
  final data = dataRaw is Map
      ? Map<String, dynamic>.from(dataRaw)
      : map;
  return PullPayload(
    users: _rows(data['users']),
    categories: _rows(data['categories']),
    products: _rows(data['products']),
    suppliers: _rows(data['suppliers']),
    inventoryEvents: _rows(data['inventory_events']),
    sales: _rows(data['sales']),
    saleItems: _rows(data['sale_items']),
    expenses: _rows(data['expenses']),
    supplierOrders: _rows(data['supplier_orders']),
    supplierOrderItems: _rows(data['supplier_order_items']),
    saleServerReceived: _rows(data['sale_server_received']),
  );
}

List<Map<String, dynamic>> _rows(Object? raw) {
  if (raw is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is Map) out.add(Map<String, dynamic>.from(item));
  }
  return out;
}

String? pullString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? pullInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? pullBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return null;
}
