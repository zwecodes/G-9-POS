import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/catalog/screens/catalog_import_screen.dart';
import '../../features/dashboard/screens/overview_screen.dart';
import '../../features/devices/screens/devices_screen.dart';
import '../../features/expenses/screens/expenses_history_screen.dart';
import '../../features/sales/screens/sales_history_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../providers/app_providers.dart';
import '../widgets/admin_shell.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (previous, next) => refresh.ping());
  ref.listen(sessionBootstrapProvider, (previous, next) => refresh.ping());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final boot = ref.read(sessionBootstrapProvider);
      final loc = state.matchedLocation;
      if (boot.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }
      final signedIn = ref.read(sessionProvider).signedIn;
      if (!signedIn) {
        return loc == '/login' ? null : '/login';
      }
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _Splash(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const OverviewScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesHistoryScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesHistoryScreen(),
          ),
          GoRoute(
            path: '/import',
            builder: (context, state) => const CatalogImportScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffScreen(),
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
          ),
        ],
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
