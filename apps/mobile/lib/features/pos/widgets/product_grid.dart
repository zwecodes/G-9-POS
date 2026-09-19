import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../products/providers/product_providers.dart';
import '../providers/barcode_listener_provider.dart';
import '../providers/cart_provider.dart';
import 'hardware_status_bar.dart';
import 'hid_scanner_focus.dart';
import 'manual_barcode_field.dart';

class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(posBarcodeListenerProvider);
    final products = ref.watch(sellableProductListProvider);
    final query = ref.watch(posSearchQueryProvider).trim().toLowerCase();
    final stocks = ref.watch(stockByProductProvider).valueOrNull ?? {};
    final barcodeError = ref.watch(barcodeLookupErrorProvider);

    return HidScannerFocus(
      child: Column(
        children: [
          const HardwareStatusBar(),
          const ManualBarcodeField(),
          if (barcodeError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ErrorText(barcodeError),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              decoration: InputDecoration(
                labelText: l10n.searchProducts,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(posSearchQueryProvider.notifier).state = value;
                ref.read(barcodeLookupErrorProvider.notifier).state = null;
              },
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => EmptyState(
                icon: Icons.error_outline,
                message: l10n.couldNotLoadProducts,
              ),
              data: (list) {
                final filtered = query.isEmpty
                    ? list
                    : list.where((p) {
                        return p.name.toLowerCase().contains(query) ||
                            (p.barcode ?? '').toLowerCase().contains(query);
                      }).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    message: context.l10n.noProductsFound,
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
      ),
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
            ref.read(barcodeLookupErrorProvider.notifier).state = null;
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
                  Text(
                    CurrencyFormatter.format(product.priceMmk),
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    'Stock $stock',
                    style: AppTextStyles.caption.copyWith(
                      color: stock <= 0
                          ? AppColors.error
                          : low
                              ? AppColors.warning
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
