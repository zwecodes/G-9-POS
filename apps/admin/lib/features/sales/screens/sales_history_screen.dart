import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesProvider);
    final money = NumberFormat('#,###');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Sales history', style: AppTextStyles.title),
        ),
        Expanded(
          child: sales.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              message: error is ApiException
                  ? error.message
                  : 'Could not load sales. Try again.',
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No sales on the server yet.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(salesProvider);
                  await ref.read(salesProvider.future);
                },
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = list[index];
                    final when = DateTime.fromMillisecondsSinceEpoch(
                      sale.createdAtMs,
                      isUtc: true,
                    ).toLocal();
                    final voided = sale.status == 'voided';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      title: Text(
                        sale.saleNumber,
                        style: AppTextStyles.body,
                      ),
                      subtitle: Text(
                        [
                          DateFormat('yyyy-MM-dd HH:mm').format(when),
                          if (voided) 'voided',
                        ].join(' · '),
                        style: AppTextStyles.caption.copyWith(
                          color: voided ? AppColors.error : null,
                        ),
                      ),
                      trailing: Text(
                        '${money.format(sale.totalAmountMmk)} MMK',
                        style: AppTextStyles.body.copyWith(
                          color: voided
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration:
                              voided ? TextDecoration.lineThrough : null,
                        ),
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
