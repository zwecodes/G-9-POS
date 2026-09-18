import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    db: ref.watch(appDatabaseProvider),
    identity: ref.watch(appIdentityProvider),
    uuids: ref.watch(uuidGeneratorProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final expenseListProvider = StreamProvider((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});
