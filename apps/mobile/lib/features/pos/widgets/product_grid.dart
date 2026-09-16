import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../products/providers/product_providers.dart';
import '../providers/cart_provider.dart';

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(sellableProductListProvider);
    final query = ref.watch(posSearchQueryProvider).trim().toLowerCase();
    final stocks = ref.watch(stockByProductProvider).valueOrNull ?? {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search or scan',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) async {
              ref.read(posSearchQueryProvider.notifier).state = value;
              final trimmed = value.trim();
              if (trimmed.isEmpty) return;
              try {
                await ref.read(cartProvider.notifier).addByBarcode(trimmed);
                ref.read(posSearchQueryProvider.notifier).state = '';
              } on RepositoryException {
                // Not a full barcode — keep filtering by name.
              }
            },
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const EmptyState(
              icon: Icons.error_outline,
              message: 'Could not load products. Try again.',
            ),
            data: (list) {
              final filtered = query.isEmpty
                  ? list
                  : list.where((p) {
                      return p.name.toLowerCase().contains(query) ||
                          (p.barcode ?? '').toLowerCase().contains(query);
                    }).toList();
              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  message: 'No products found — try a different name',
                );
              }
              final width = MediaQuery.sizeOf(context).width;
              final columns = width >= AppBreakpoints.tablet ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.8,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final stock = stocks[product.id] ?? 0;
                  return _ProductCard(product: product, stock: stock);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.stock});

  final Product product;
  final int stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low = stock <= product.lowStockThreshold;
    return Card(
      color: AppColors.surface,
      child: InkWell(
        onTap: () {
          try {
            ref.read(cartProvider.notifier).addProduct(product);
          } on RepositoryException {
            // Inactive products are filtered from sellable list.
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: AppColors.primaryLight,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                        size: AppSpacing.xl,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cartItemName,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    CurrencyFormatter.format(product.priceMmk),
                    style: AppTextStyles.cartItemPrice,
                  ),
                ],
              ),
              if (low)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: AppSpacing.xs,
                    backgroundColor: AppColors.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
