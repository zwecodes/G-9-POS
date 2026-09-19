import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_status.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_panel.dart';
import '../widgets/product_grid.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.navPos),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= AppBreakpoints.tablet) {
                  return const Row(
                    children: [
                      Expanded(flex: 6, child: ProductGrid()),
                      Expanded(flex: 4, child: CartPanel()),
                    ],
                  );
                }
                return const ProductGrid();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => _openPhoneCart(context),
              icon: Badge(
                isLabelVisible: ref.watch(cartProvider).itemCount > 0,
                label: Text('${ref.watch(cartProvider).itemCount}'),
                child: const Icon(Icons.shopping_cart, color: AppColors.onPrimary),
              ),
              label: Text(context.l10n.cart, style: AppTextStyles.buttonPrimary),
            ),
    );
  }

  void _openPhoneCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: const CartPanel(embedded: false),
        );
      },
    );
  }
}
