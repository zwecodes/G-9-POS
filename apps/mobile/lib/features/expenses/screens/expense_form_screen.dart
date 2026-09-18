import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/expense_providers.dart';
import '../repositories/expense_repository.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = kExpenseCategories.first;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ShopDateUtils.todayShopDateString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add expense'),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text('Date: $today', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Category *'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _category,
                      items: [
                        for (final category in kExpenseCategories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _category = value);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Amount (MMK) *',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                ErrorText(_error),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Save expense',
                  busy: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(expenseRepositoryProvider).create(
            ExpenseDraft(
              category: _category,
              amountMmk: amount,
              note: _note.text,
            ),
          );
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
        _error = 'Could not save the expense. Try again.';
      });
    }
  }
}
