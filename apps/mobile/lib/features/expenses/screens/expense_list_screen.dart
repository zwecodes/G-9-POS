import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/expense_providers.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseListProvider);
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: ErrorText(_error),
            ),
          Expanded(
            child: expenses.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const EmptyState(
                icon: Icons.error_outline,
                message: 'Could not load expenses. Try again.',
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'No expenses yet — add the first one',
                    action: TextButton(
                      onPressed: () => context.push('/settings/expenses/new'),
                      child: const Text('Add expense'),
                    ),
                  );
                }
                final sections = _groupByDate(list);
                return ListView.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Text(
                            section.date,
                            style: AppTextStyles.sectionHeader,
                          ),
                        ),
                        for (final expense in section.items)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            title: Text(
                              expense.category,
                              style: AppTextStyles.cartItemName,
                            ),
                            subtitle: expense.note == null ||
                                    expense.note!.isEmpty
                                ? null
                                : Text(
                                    expense.note!,
                                    style: AppTextStyles.caption,
                                  ),
                            trailing: Text(
                              CurrencyFormatter.format(expense.amountMmk),
                              style: AppTextStyles.cartItemPrice,
                            ),
                            onLongPress: isOwner
                                ? () => _confirmDelete(expense)
                                : null,
                          ),
                        const Divider(height: 1),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/settings/expenses/new'),
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this expense?', style: AppTextStyles.title),
          content: Text(
            '${expense.category} — ${CurrencyFormatter.format(expense.amountMmk)}',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(expenseRepositoryProvider).delete(expense.id);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not delete the expense. Try again.');
    }
  }
}

class _DateSection {
  const _DateSection({required this.date, required this.items});

  final String date;
  final List<Expense> items;
}

List<_DateSection> _groupByDate(List<Expense> list) {
  final map = <String, List<Expense>>{};
  for (final expense in list) {
    map.putIfAbsent(expense.expenseDate, () => []).add(expense);
  }
  final dates = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates) _DateSection(date: date, items: map[date]!),
  ];
}
