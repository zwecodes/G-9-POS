import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../categories/providers/category_providers.dart';
import '../providers/product_providers.dart';
import '../repositories/product_repository.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _unit = TextEditingController(text: 'pcs');
  final _threshold = TextEditingController(text: '5');
  final _newCategory = TextEditingController();
  String? _categoryId;
  String? _error;
  var _loaded = false;
  var _saving = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _price.dispose();
    _cost.dispose();
    _unit.dispose();
    _threshold.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loaded || !_isEdit) {
      _loaded = true;
      return;
    }
    final product = await ref.read(productRepositoryProvider).getById(widget.productId!);
    if (!mounted || product == null) return;
    _name.text = product.name;
    _barcode.text = product.barcode ?? '';
    _price.text = '${product.priceMmk}';
    _cost.text = product.costPriceMmk == null ? '' : '${product.costPriceMmk}';
    _unit.text = product.unit;
    _threshold.text = '${product.lowStockThreshold}';
    _categoryId = product.categoryId;
    _loaded = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                const SizedBox(height: AppSpacing.md),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Category'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _categoryId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        for (final category in categories)
                          DropdownMenuItem(value: category.id, child: Text(category.name)),
                      ],
                      onChanged: (id) => setState(() => _categoryId = id),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _newCategory,
                  decoration: const InputDecoration(
                    labelText: 'Or type a new category name',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _barcode,
                  decoration: const InputDecoration(labelText: 'Barcode'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Price *'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cost price',
                    hintText: 'Add cost price to see profit in reports',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _threshold,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Low stock threshold'),
                ),
                ErrorText(_error),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: _confirmDelete,
                    child: Text(
                      'Delete product',
                      style: AppTextStyles.body.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimaryButton(
                label: 'Save',
                busy: _saving,
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var categoryId = _categoryId;
      final newName = _newCategory.text.trim();
      if (newName.isNotEmpty) {
        final created = await ref.read(categoryRepositoryProvider).create(name: newName);
        categoryId = created.id;
      }
      final draft = ProductDraft(
        name: _name.text,
        categoryId: categoryId,
        barcode: _barcode.text,
        priceMmk: int.tryParse(_price.text) ?? -1,
        costPriceMmk: int.tryParse(_cost.text),
        unit: _unit.text,
        lowStockThreshold: int.tryParse(_threshold.text) ?? 5,
      );
      if (_isEdit) {
        await ref.read(productRepositoryProvider).update(widget.productId!, draft);
      } else {
        await ref.read(productRepositoryProvider).create(draft);
      }
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
        _error = 'Could not save the product. Try again.';
      });
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this product?', style: AppTextStyles.title),
          content: const Text(
            'It will be hidden from selling. Past sales stay as they are.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Keep it', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: AppTextStyles.body.copyWith(color: AppColors.error)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(productRepositoryProvider).delete(widget.productId!);
      if (!mounted) return;
      context.pop();
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }
}
