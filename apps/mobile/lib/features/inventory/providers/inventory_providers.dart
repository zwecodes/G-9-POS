import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    db: ref.watch(appDatabaseProvider),
    identity: ref.watch(appIdentityProvider),
    uuids: ref.watch(uuidGeneratorProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final productStockProvider =
    FutureProvider.family<int, String>((ref, productId) {
  return ref.watch(inventoryRepositoryProvider).stockOf(productId);
});

final stockByProductProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchStockByProduct();
});

final stockLevelsProvider = StreamProvider<List<ProductStock>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchStockLevels();
});

final lowStockProvider = StreamProvider<List<ProductStock>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchLowStock();
});

final productStockLevelProvider =
    FutureProvider.family<ProductStock?, String>((ref, productId) {
  return ref.watch(inventoryRepositoryProvider).stockLevelFor(productId);
});
