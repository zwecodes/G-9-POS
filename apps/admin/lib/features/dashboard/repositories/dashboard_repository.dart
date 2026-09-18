import '../../../core/api/api_client.dart';

class DeviceSummary {
  const DeviceSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.isActivePos,
    this.lastSyncAtMs,
    this.revokedAtMs,
  });

  final String id;
  final String name;
  final String type;
  final bool isActivePos;
  final int? lastSyncAtMs;
  final int? revokedAtMs;

  factory DeviceSummary.fromJson(Map<String, dynamic> json) {
    return DeviceSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Device',
      type: json['type'] as String? ?? '',
      isActivePos: json['is_active_pos'] == true,
      lastSyncAtMs: (json['last_sync_at'] as num?)?.toInt(),
      revokedAtMs: (json['revoked_at'] as num?)?.toInt(),
    );
  }
}

class DashboardOverview {
  const DashboardOverview({
    required this.date,
    required this.revenueMmk,
    required this.lowStockCount,
    this.activeDevice,
    required this.devices,
  });

  final String date;
  final int revenueMmk;
  final int lowStockCount;
  final DeviceSummary? activeDevice;
  final List<DeviceSummary> devices;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    final devicesRaw = json['devices'];
    final devices = <DeviceSummary>[];
    if (devicesRaw is List) {
      for (final row in devicesRaw) {
        if (row is Map<String, dynamic>) {
          devices.add(DeviceSummary.fromJson(row));
        }
      }
    }
    DeviceSummary? active;
    final activeRaw = json['active_device'];
    if (activeRaw is Map<String, dynamic>) {
      active = DeviceSummary.fromJson(activeRaw);
    }
    return DashboardOverview(
      date: json['date'] as String? ?? '',
      revenueMmk: (json['revenue_mmk'] as num?)?.toInt() ?? 0,
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      activeDevice: active,
      devices: devices,
    );
  }
}

class CatalogImportResult {
  const CatalogImportResult({
    required this.productsCreated,
    required this.categoriesCreated,
    required this.inventoryEventsCreated,
  });

  final int productsCreated;
  final int categoriesCreated;
  final int inventoryEventsCreated;

  factory CatalogImportResult.fromJson(Map<String, dynamic> json) {
    return CatalogImportResult(
      productsCreated: (json['products_created'] as num?)?.toInt() ?? 0,
      categoriesCreated: (json['categories_created'] as num?)?.toInt() ?? 0,
      inventoryEventsCreated:
          (json['inventory_events_created'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardOverview> overview() async {
    final data = await _api.getJson('/v1/dashboard/overview');
    return DashboardOverview.fromJson(data);
  }

  Future<CatalogImportResult> importCatalog({
    required String fileName,
    required List<int> bytes,
  }) async {
    final data = await _api.postMultipartFile(
      path: '/v1/catalog/import',
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
    );
    return CatalogImportResult.fromJson(data);
  }

  Future<List<AdminUser>> listUsers() async {
    final rows = await _api.getList('/v1/users');
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) AdminUser.fromJson(row),
    ];
  }

  Future<AdminUser> createStaff({
    required String name,
    required String pin,
  }) async {
    final data = await _api.postJson(
      '/v1/users',
      {'name': name.trim(), 'pin': pin},
      auth: true,
    );
    return AdminUser.fromJson(data);
  }

  Future<List<DeviceSummary>> listDevices() async {
    final rows = await _api.getList('/v1/devices');
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) DeviceSummary.fromJson(row),
    ];
  }

  Future<void> revokeDevice(String id) async {
    await _api.postJson('/v1/devices/$id/revoke', const {}, auth: true);
  }

  Future<List<SaleSummary>> listSales() async {
    final rows = await _api.getList('/v1/sales');
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) SaleSummary.fromJson(row),
    ];
  }

  Future<List<ExpenseSummary>> listExpenses() async {
    final rows = await _api.getList('/v1/expenses');
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) ExpenseSummary.fromJson(row),
    ];
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.role,
    this.username,
  });

  final String id;
  final String name;
  final String role;
  final String? username;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      username: json['username'] as String?,
    );
  }
}

class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.saleNumber,
    required this.totalAmountMmk,
    required this.status,
    required this.createdAtMs,
    required this.operatorId,
  });

  final String id;
  final String saleNumber;
  final int totalAmountMmk;
  final String status;
  final int createdAtMs;
  final String operatorId;

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: json['id'] as String? ?? '',
      saleNumber: json['sale_number'] as String? ?? '',
      totalAmountMmk: (json['total_amount_mmk'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      createdAtMs: (json['created_at'] as num?)?.toInt() ?? 0,
      operatorId: json['operator_id'] as String? ?? '',
    );
  }
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.id,
    required this.category,
    required this.amountMmk,
    required this.expenseDate,
    this.note,
  });

  final String id;
  final String category;
  final int amountMmk;
  final String expenseDate;
  final String? note;

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      amountMmk: (json['amount_mmk'] as num?)?.toInt() ?? 0,
      expenseDate: json['expense_date'] as String? ?? '',
      note: json['note'] as String?,
    );
  }
}
