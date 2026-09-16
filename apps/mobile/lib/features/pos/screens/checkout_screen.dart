import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('TOTAL', style: AppTextStyles.sectionHeader),
            Text(
              CurrencyFormatter.format(cart.totalAmountMmk),
              style: AppTextStyles.saleTotal,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Payment: CASH', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ErrorText(_error),
            const Spacer(),
            PrimaryButton(
              label: 'COMPLETE SALE',
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
        _error = 'Could not complete the sale. Try again.';
      });
    }
  }
}
