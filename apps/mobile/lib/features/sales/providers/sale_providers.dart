import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../repositories/sale_repository.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(
    db: ref.watch(appDatabaseProvider),
    identity: ref.watch(appIdentityProvider),
    uuids: ref.watch(uuidGeneratorProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final saleListProvider = StreamProvider((ref) {
  return ref.watch(saleRepositoryProvider).watchAll();
});
