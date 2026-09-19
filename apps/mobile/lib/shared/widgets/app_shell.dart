import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../features/pos/providers/cart_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cartCount = ref.watch(cartProvider).itemCount;
    final location = GoRouterState.of(context).uri.path;
    final hideNav = location.contains('/checkout') ||
        location.contains('/complete') ||
        location.contains('/products/') ||
        location.contains('/settings/');

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideNav
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              indicatorColor: AppColors.primaryLight,
              destinations: [
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.point_of_sale_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(
                      Icons.point_of_sale,
                      color: AppColors.primary,
                    ),
                  ),
                  label: l10n.navPos,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(
                    Icons.inventory_2,
                    color: AppColors.primary,
                  ),
                  label: l10n.navProducts,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bar_chart_outlined),
                  selectedIcon: const Icon(
                    Icons.bar_chart,
                    color: AppColors.primary,
                  ),
                  label: l10n.navReports,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(
                    Icons.settings,
                    color: AppColors.primary,
                  ),
                  label: l10n.navSettings,
                ),
              ],
            ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
