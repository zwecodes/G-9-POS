import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../sales/providers/sale_providers.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _error;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.total.toUpperCase(), style: AppTextStyles.sectionHeader),
            Text(
              CurrencyFormatter.format(cart.totalAmountMmk),
              style: AppTextStyles.saleTotal,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.paymentCash, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ErrorText(_error),
            const Spacer(),
            PrimaryButton(
              label: context.l10n.completeSale,
              height: AppSpacing.completeSaleButton,
              busy: _busy,
              onPressed: cart.isEmpty ? null : _complete,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete() async {
    final cart = ref.read(cartProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final completed = await ref.read(saleRepositoryProvider).completeSale(
            lines: cart.toSaleLines(),
            discountAmountMmk: cart.discountAmountMmk,
            note: cart.note,
          );
      if (!mounted) return;
      ref.read(cartProvider.notifier).clear();
      context.go('/pos/complete', extra: completed);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.couldNotCompleteSale;
      });
    }
  }
}
