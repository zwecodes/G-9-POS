import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/product_providers.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'Inventory',
              icon: const Icon(Icons.warehouse_outlined),
              onPressed: () => context.push('/products/inventory'),
            ),
          const SyncStatusButton(),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const EmptyState(
                icon: Icons.error_outline,
                message: 'Could not load products. Try again.',
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'No products yet — add your first product',
                    action: isOwner
                        ? TextButton(
                            onPressed: () => context.push('/products/new'),
                            child: const Text('Add product'),
                          )
                        : null,
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = list[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      title: Text(product.name, style: AppTextStyles.cartItemName),
                      subtitle: Text(
                        CurrencyFormatter.format(product.priceMmk),
                        style: AppTextStyles.caption,
                      ),
                      onTap: isOwner
                          ? () => context.push('/products/${product.id}')
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => context.push('/products/new'),
              child: const Icon(Icons.add, color: AppColors.onPrimary),
            )
          : null,
    );
  }
}
