import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class ExpensesHistoryScreen extends ConsumerWidget {
  const ExpensesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final money = NumberFormat('#,###');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Expenses', style: AppTextStyles.title),
        ),
        Expanded(
          child: expenses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              message: error is ApiException
                  ? error.message
                  : 'Could not load expenses. Try again.',
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.payments_outlined,
                  message: 'No expenses on the server yet.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(expensesProvider);
                  await ref.read(expensesProvider.future);
                },
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final expense = list[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      title: Text(
                        expense.category,
                        style: AppTextStyles.body,
                      ),
                      subtitle: Text(
                        [
                          expense.expenseDate,
                          if (expense.note != null && expense.note!.isNotEmpty)
                            expense.note!,
                        ].join(' · '),
                        style: AppTextStyles.caption,
                      ),
                      trailing: Text(
                        '${money.format(expense.amountMmk)} MMK',
                        style: AppTextStyles.body,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
