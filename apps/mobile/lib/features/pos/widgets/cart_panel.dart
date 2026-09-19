import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/cart_provider.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, this.embedded = true});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cart = ref.watch(cartProvider);
    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          Expanded(
            child: cart.isEmpty
                ? EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    message: l10n.cartEmpty,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: cart.lines.length,
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return Dismissible(
                        key: ValueKey(line.productId),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => ref
                            .read(cartProvider.notifier)
                            .remove(line.productId),
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: AppColors.error,
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: const Icon(
                            Icons.delete,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        child: _CartRow(line: line),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(l10n.total.toUpperCase(), style: AppTextStyles.sectionHeader),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(cart.totalAmountMmk),
                          style: AppTextStyles.saleTotal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: context.l10n.completeSale,
                  height: AppSpacing.completeSaleButton,
                  onPressed: cart.isEmpty ? null : () => context.push('/pos/checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends ConsumerWidget {
  const _CartRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(line.name, style: AppTextStyles.cartItemName, maxLines: 2),
          ),
          IconButton(
            iconSize: AppSpacing.lg,
            padding: const EdgeInsets.all(AppSpacing.md),
            onPressed: () => cart.decrement(line.productId),
            icon: const Icon(Icons.remove),
          ),
          InkWell(
            onTap: () => _editQuantity(context, ref),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: AppSpacing.minTapTarget),
              child: Text(
                '${line.quantity}',
                textAlign: TextAlign.center,
                style: AppTextStyles.cartItemName,
              ),
            ),
          ),
          IconButton(
            iconSize: AppSpacing.lg,
            padding: const EdgeInsets.all(AppSpacing.md),
            onPressed: () => cart.increment(line.productId),
            icon: const Icon(Icons.add),
          ),
          SizedBox(
            width: AppSpacing.xxl + AppSpacing.lg,
            child: Text(
              CurrencyFormatter.formatCompact(line.subtotalMmk),
              textAlign: TextAlign.right,
              style: AppTextStyles.cartItemPrice,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editQuantity(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: '${line.quantity}');
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.quantity, style: AppTextStyles.title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(labelText: context.l10n.quantity),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.keep, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
              child: Text(context.l10n.set, style: AppTextStyles.body.copyWith(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null) {
      try {
        ref.read(cartProvider.notifier).setQuantity(line.productId, result);
      } on RepositoryException {
        // Quantity of 0 removes the line — already handled.
      }
    }
  }
}
