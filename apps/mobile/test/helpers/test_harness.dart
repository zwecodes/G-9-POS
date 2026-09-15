import 'package:g9pos/core/auth/app_identity.dart';
import 'package:g9pos/core/auth/auth_service.dart';
import 'package:g9pos/core/auth/device_id_service.dart';
import 'package:g9pos/core/auth/pin_service.dart';
import 'package:g9pos/core/auth/token_cache.dart';
import 'package:g9pos/core/database/app_database.dart';
import 'package:g9pos/core/database/connection.dart';
import 'package:g9pos/features/auth/repositories/auth_repository.dart';
import 'package:g9pos/features/categories/repositories/category_repository.dart';
import 'package:g9pos/features/inventory/repositories/inventory_repository.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';
import 'package:g9pos/features/sales/repositories/sale_repository.dart';
import 'package:logger/logger.dart';

void silenceLoggers() {
  Logger.level = Level.off;
}

AppIdentity testIdentity({
  String deviceId = 'device-1',
  String operatorId = 'owner-1',
  String operatorRole = 'owner',
}) {
  return AppIdentity(
    deviceId: () async => deviceId,
    operatorId: () => operatorId,
    operatorRole: () => operatorRole,
  );
}

class TestRepos {
  TestRepos({
    required this.db,
    required this.identity,
    required this.categories,
    required this.products,
    required this.inventory,
    required this.sales,
  });

  final AppDatabase db;
  final AppIdentity identity;
  final CategoryRepository categories;
  final ProductRepository products;
  final InventoryRepository inventory;
  final SaleRepository sales;

  Future<void> close() => db.close();
}

TestRepos openTestRepos({AppIdentity? identity}) {
  silenceLoggers();
  final db = openMemoryDatabase();
  final id = identity ?? testIdentity();
  return TestRepos(
    db: db,
    identity: id,
    categories: CategoryRepository(db: db, identity: id),
    products: ProductRepository(db: db, identity: id),
    inventory: InventoryRepository(db: db, identity: id),
    sales: SaleRepository(db: db, identity: id),
  );
}

AuthRepository memoryAuthRepository({
  required AppDatabase db,
  AuthPoster? poster,
  TokenCache? tokens,
}) {
  silenceLoggers();
  final cache = tokens ?? TokenCache(memory: {});
  return AuthRepository(
    auth: AuthService(
      tokens: cache,
      deviceIds: DeviceIdService(seedId: 'device-1'),
      deviceName: 'G9POS',
      deviceType: 'tablet',
      poster: poster,
    ),
    pins: PinService(db: db),
    tokens: cache,
    db: db,
  );
}
