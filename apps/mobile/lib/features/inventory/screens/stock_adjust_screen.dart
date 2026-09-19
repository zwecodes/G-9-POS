import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';

enum _AdjustDirection { add, remove }

class StockAdjustScreen extends ConsumerStatefulWidget {
  const StockAdjustScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<StockAdjustScreen> createState() => _StockAdjustScreenState();
}

class _StockAdjustScreenState extends ConsumerState<StockAdjustScreen> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  _AdjustDirection? _direction;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adjustStock)),
        body: EmptyState(
          icon: Icons.lock_outline,
          message: l10n.stockOwnerOnly,
        ),
      );
    }

    final level = ref.watch(productStockLevelProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adjustStock),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: level.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const EmptyState(
                icon: Icons.error_outline,
                message: 'Could not load this product. Try again.',
              ),
              data: (row) {
                if (row == null) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'That product is no longer available.',
                  );
                }
                final stockColor = row.isOutOfStock
                    ? AppColors.error
                    : row.isLowStock
                        ? AppColors.warning
                        : AppColors.success;
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(row.product.name, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.currentStock(row.currentStock),
                      style: AppTextStyles.saleTotal.copyWith(color: stockColor),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: AppSpacing.keyActionButton,
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                        _direction = _AdjustDirection.add;
                                        _error = null;
                                      }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: BorderSide(
                                  color: _direction == _AdjustDirection.add
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                  width: _direction == _AdjustDirection.add
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child: Text(l10n.addStock),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SizedBox(
                            height: AppSpacing.keyActionButton,
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                        _direction = _AdjustDirection.remove;
                                        _error = null;
                                      }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(
                                  color: _direction == _AdjustDirection.remove
                                      ? AppColors.error
                                      : AppColors.textMuted,
                                  width: _direction == _AdjustDirection.remove
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child: Text(l10n.removeStock),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: context.l10n.quantityRequired,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.l10n.noteRequired,
                        hintText: l10n.whyStockChanging,
                      ),
                    ),
                    ErrorText(_error),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: l10n.saveStockChange,
                      busy: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final direction = _direction;
    if (direction == null) {
      setState(() => _error = 'Choose add stock or remove stock.');
      return;
    }
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    if (quantity <= 0) {
      setState(() => _error = 'Enter a quantity greater than zero.');
      return;
    }
    final note = _note.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'Please add a note for this stock change.');
      return;
    }

    final delta =
        direction == _AdjustDirection.add ? quantity : -quantity;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(inventoryRepositoryProvider).adjust(
            productId: widget.productId,
            quantityDelta: delta,
            note: note,
          );
      ref.invalidate(productStockLevelProvider(widget.productId));
      if (!mounted) return;
      context.pop();
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the stock change. Try again.';
      });
    }
  }
}
