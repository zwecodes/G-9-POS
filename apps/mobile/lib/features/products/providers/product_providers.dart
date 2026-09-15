import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    db: ref.watch(appDatabaseProvider),
    identity: ref.watch(appIdentityProvider),
    uuids: ref.watch(uuidGeneratorProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final productListProvider = StreamProvider((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

final sellableProductListProvider = StreamProvider((ref) {
  return ref.watch(productRepositoryProvider).watchSellable();
});
