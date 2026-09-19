import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';
import '../repositories/inventory_repository.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventory),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: isOwner
                ? const _OwnerInventoryBody()
                : EmptyState(
                    icon: Icons.lock_outline,
                    message: l10n.inventoryOwnerOnly,
                  ),
          ),
        ],
      ),
    );
  }
}

class _OwnerInventoryBody extends ConsumerStatefulWidget {
  const _OwnerInventoryBody();

  @override
  ConsumerState<_OwnerInventoryBody> createState() =>
      _OwnerInventoryBodyState();
}

class _OwnerInventoryBodyState extends ConsumerState<_OwnerInventoryBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final levels = ref.watch(stockLevelsProvider);
    return levels.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => EmptyState(
        icon: Icons.error_outline,
        message: l10n.couldNotLoadStock,
      ),
      data: (rows) {
        final low = rows.where((row) => row.isLowStock).toList();
        final out = rows.where((row) => row.isOutOfStock).toList();
        return Column(
          children: [
            TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: l10n.allStock(rows.length)),
                Tab(text: l10n.lowStock(low.length)),
                Tab(text: l10n.outOfStock(out.length)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _StockList(rows: rows, emptyMessage: l10n.noProductsStock),
                  _StockList(
                    rows: low,
                    emptyMessage: l10n.noLowStock,
                  ),
                  _StockList(
                    rows: out,
                    emptyMessage: l10n.noOutOfStock,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({
    required this.rows,
    required this.emptyMessage,
  });

  final List<ProductStock> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minVerticalPadding: AppSpacing.sm,
          title: Text(row.product.name, style: AppTextStyles.cartItemName),
          trailing: Text(
            '${row.currentStock}',
            style: AppTextStyles.title.copyWith(color: _stockColor(row)),
          ),
          onTap: () => context.push('/products/inventory/${row.product.id}'),
        );
      },
    );
  }

  Color _stockColor(ProductStock row) {
    if (row.isOutOfStock) return AppColors.error;
    if (row.isLowStock) return AppColors.warning;
    return AppColors.success;
  }
}
