import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/pin_screen.dart';
import '../../features/expenses/screens/expense_form_screen.dart';
import '../../features/expenses/screens/expense_list_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/stock_adjust_screen.dart';
import '../../features/pos/screens/checkout_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/pos/screens/sale_complete_screen.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/products/screens/product_list_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/sales/repositories/sale_repository.dart';
import '../../features/sales/screens/sale_detail_screen.dart';
import '../../features/sales/screens/sales_history_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/sync_status_screen.dart';
import '../widgets/app_shell.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (previous, next) => refresh.ping());
  ref.listen(sessionBootstrapProvider, (previous, next) => refresh.ping());

  return GoRouter(
    initialLocation: '/pos',
    refreshListenable: refresh,
    redirect: (context, state) {
      final boot = ref.read(sessionBootstrapProvider);
      final loc = state.matchedLocation;
      if (boot.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }
      final session = ref.read(sessionProvider);
      final onAuth = loc == '/login' || loc == '/pin' || loc == '/splash';
      if (!session.isUnlocked) {
        if (session.hasJwt) {
          return loc == '/pin' ? null : '/pin';
        }
        if (loc == '/login' || loc == '/pin') return null;
        return '/login';
      }
      if (onAuth) return '/pos';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/pin', builder: (context, state) => const PinScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pos',
                builder: (context, state) => const PosScreen(),
                routes: [
                  GoRoute(
                    path: 'checkout',
                    builder: (context, state) => const CheckoutScreen(),
                  ),
                  GoRoute(
                    path: 'complete',
                    builder: (context, state) {
                      final sale = state.extra as CompletedSale?;
                      if (sale == null) return const PosScreen();
                      return SaleCompleteScreen(sale: sale);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ProductFormScreen(),
                  ),
                  GoRoute(
                    path: 'inventory',
                    builder: (context, state) => const InventoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':productId',
                        builder: (context, state) => StockAdjustScreen(
                          productId: state.pathParameters['productId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ProductFormScreen(
                      productId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'sync',
                    builder: (context, state) => const SyncStatusScreen(),
                  ),
                  GoRoute(
                    path: 'expenses',
                    builder: (context, state) => const ExpenseListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const ExpenseFormScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'sales',
                    builder: (context, state) => const SalesHistoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => SaleDetailScreen(
                          saleId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
