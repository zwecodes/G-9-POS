import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final overviewProvider = FutureProvider<DashboardOverview>((ref) {
  return ref.watch(dashboardRepositoryProvider).overview();
});
