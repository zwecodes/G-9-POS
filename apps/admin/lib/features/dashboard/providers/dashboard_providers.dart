import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final overviewProvider = FutureProvider<DashboardOverview>((ref) {
  return ref.watch(dashboardRepositoryProvider).overview();
});

final usersProvider = FutureProvider<List<AdminUser>>((ref) {
  return ref.watch(dashboardRepositoryProvider).listUsers();
});

final devicesProvider = FutureProvider<List<DeviceSummary>>((ref) {
  return ref.watch(dashboardRepositoryProvider).listDevices();
});

final salesProvider = FutureProvider<List<SaleSummary>>((ref) {
  return ref.watch(dashboardRepositoryProvider).listSales();
});

final expensesProvider = FutureProvider<List<ExpenseSummary>>((ref) {
  return ref.watch(dashboardRepositoryProvider).listExpenses();
});
