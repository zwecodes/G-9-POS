import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../sales/repositories/sale_repository.dart';

class SaleCompleteScreen extends StatefulWidget {
  const SaleCompleteScreen({super.key, required this.sale});

  final CompletedSale sale;

  @override
  State<SaleCompleteScreen> createState() => _SaleCompleteScreenState();
}

class _SaleCompleteScreenState extends State<SaleCompleteScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/pos');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.success,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.onPrimary,
                  size: AppSpacing.xxl,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(widget.sale.saleNumber, style: AppTextStyles.buttonPrimary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  CurrencyFormatter.format(widget.sale.totalAmountMmk),
                  style: AppTextStyles.saleTotal.copyWith(color: AppColors.onPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No printer connected',
                  style: AppTextStyles.body.copyWith(color: AppColors.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
