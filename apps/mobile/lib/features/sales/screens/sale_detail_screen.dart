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
import '../../auth/providers/auth_providers.dart';
import '../providers/sale_providers.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  Sale? _sale;
  List<SaleItem> _items = const [];
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(saleRepositoryProvider);
    final sale = await repo.getById(widget.saleId);
    final items = sale == null ? <SaleItem>[] : await repo.itemsFor(widget.saleId);
    if (!mounted) return;
    setState(() {
      _sale = sale;
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final sale = _sale;
    if (sale == null) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.receipt_long,
          message: l10n.saleUnavailable,
        ),
      );
    }
    final voided = sale.status == 'voided';
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    return Scaffold(
      appBar: AppBar(title: Text(sale.saleNumber)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            CurrencyFormatter.format(sale.totalAmountMmk),
            style: AppTextStyles.saleTotal,
          ),
          if (voided)
            Text(
              l10n.cancelled,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productNameSnapshot, style: AppTextStyles.cartItemName),
              subtitle: Text('x${item.quantity}', style: AppTextStyles.caption),
              trailing: Text(
                CurrencyFormatter.format(item.subtotalMmk),
                style: AppTextStyles.cartItemPrice,
              ),
            ),
          ErrorText(_error),
          if (isOwner && !voided) ...[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.cancelThisSale,
              color: AppColors.error,
              onPressed: _confirmVoid,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmVoid() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = context.l10n;
        return AlertDialog(
          title: Text(dialogL10n.cancelSaleTitle, style: AppTextStyles.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dialogL10n.cancelSaleBody,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                dialogL10n.keep,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                dialogL10n.cancelThisSale,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (ok != true || !mounted) return;
    try {
      await ref.read(saleRepositoryProvider).voidSale(
            saleId: widget.saleId,
            reason: reason,
          );
      if (!mounted) return;
      await _load();
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }
}
