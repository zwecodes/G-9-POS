import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/app_providers.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _navItems = [
  _NavItem('/', 'Overview', Icons.dashboard_outlined, Icons.dashboard),
  _NavItem('/sales', 'Sales', Icons.receipt_long_outlined, Icons.receipt_long),
  _NavItem(
    '/expenses',
    'Expenses',
    Icons.payments_outlined,
    Icons.payments,
  ),
  _NavItem(
    '/import',
    'Import',
    Icons.upload_file_outlined,
    Icons.upload_file,
  ),
  _NavItem('/staff', 'Staff', Icons.badge_outlined, Icons.badge),
  _NavItem(
    '/devices',
    'Devices',
    Icons.phone_android_outlined,
    Icons.phone_android,
  ),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(String location) {
    for (var i = 0; i < _navItems.length; i++) {
      final path = _navItems[i].path;
      if (path == '/') {
        if (location == '/') return 0;
        continue;
      }
      if (location == path || location.startsWith('$path/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('G9POS Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Text(
                session.userName ?? '',
                style: AppTextStyles.caption,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            child: Text(
              'Sign out',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (index) =>
                context.go(_navItems[index].path),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final item in _navItems)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
