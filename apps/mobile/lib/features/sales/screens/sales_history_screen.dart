import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/sale_providers.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sales = ref.watch(saleListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.salesHistory),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: sales.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => EmptyState(
                icon: Icons.error_outline,
                message: l10n.couldNotLoadSales,
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long,
                    message: l10n.noSalesToday,
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = list[index];
                    final voided = sale.status == 'voided';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      title: Text(sale.saleNumber, style: AppTextStyles.cartItemName),
                      subtitle: Text(
                        ShopDateUtils.formatShopDateTime(sale.createdAt),
                        style: AppTextStyles.caption,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(sale.totalAmountMmk),
                            style: AppTextStyles.cartItemPrice,
                          ),
                          if (voided)
                            Text(
                              l10n.cancelled,
                              style: AppTextStyles.caption.copyWith(color: AppColors.error),
                            ),
                        ],
                      ),
                      onTap: () => context.push('/settings/sales/${sale.id}'),
                    );
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
