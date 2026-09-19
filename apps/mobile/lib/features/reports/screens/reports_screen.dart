import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: isOwner
                ? const _OwnerReportsBody()
                : EmptyState(
                    icon: Icons.lock_outline,
                    message: l10n.reportsOwnerOnly,
                  ),
          ),
        ],
      ),
    );
  }
}

class _OwnerReportsBody extends ConsumerWidget {
  const _OwnerReportsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final range = ref.watch(reportRangeProvider);
    final summary = ref.watch(reportSummaryProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: SegmentedButton<ReportPeriod>(
            segments: [
              ButtonSegment(
                value: ReportPeriod.today,
                label: Text(l10n.today),
              ),
              ButtonSegment(
                value: ReportPeriod.thisWeek,
                label: Text(l10n.thisWeek),
              ),
              ButtonSegment(
                value: ReportPeriod.custom,
                label: Text(l10n.custom),
              ),
            ],
            selected: {range.period},
            onSelectionChanged: (values) async {
              final period = values.first;
              if (period == ReportPeriod.today) {
                ref.read(reportRangeProvider.notifier).state =
                    ReportRange.today();
              } else if (period == ReportPeriod.thisWeek) {
                ref.read(reportRangeProvider.notifier).state =
                    ReportRange.thisWeek();
              } else {
                await _pickCustomRange(context, ref, range);
              }
            },
          ),
        ),
        if (range.period == ReportPeriod.custom &&
            range.customFromYmd != null &&
            range.customToYmd != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TextButton(
              onPressed: () => _pickCustomRange(context, ref, range),
              child: Text(
                '${range.customFromYmd} → ${range.customToYmd}',
                style: AppTextStyles.caption,
              ),
            ),
          ),
        Expanded(
          child: summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              message: l10n.couldNotLoadReport,
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(l10n.revenue, style: AppTextStyles.sectionHeader),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  CurrencyFormatter.format(data.revenueMmk),
                  style: AppTextStyles.saleTotal,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.profit, style: AppTextStyles.sectionHeader),
                const SizedBox(height: AppSpacing.xs),
                if (data.incompleteProfit || data.profitMmk == null)
                  Text(
                    l10n.incompleteProfit,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    CurrencyFormatter.format(data.profitMmk!),
                    style: AppTextStyles.saleTotal,
                  ),
                const SizedBox(height: AppSpacing.lg),
                _MetricRow(label: l10n.sales, value: '${data.saleCount}'),
                _MetricRow(label: l10n.itemsSold, value: '${data.itemsSold}'),
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.topProducts, style: AppTextStyles.sectionHeader),
                const SizedBox(height: AppSpacing.sm),
                if (data.topProducts.isEmpty)
                  Text(
                    l10n.noSalesInPeriod,
                    style: AppTextStyles.caption,
                  )
                else
                  for (var i = 0; i < data.topProducts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        '${i + 1}. ${data.topProducts[i].name}  ×${data.topProducts[i].quantitySold}',
                        style: AppTextStyles.body,
                      ),
                    ),
                const SizedBox(height: AppSpacing.xl),
                Text(l10n.expenses, style: AppTextStyles.sectionHeader),
                const SizedBox(height: AppSpacing.sm),
                if (data.expenses.isEmpty)
                  Text(
                    l10n.noExpensesInPeriod,
                    style: AppTextStyles.caption,
                  )
                else ...[
                  for (final row in data.expenses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(row.category, style: AppTextStyles.body),
                          ),
                          Text(
                            CurrencyFormatter.formatCompact(row.amountMmk),
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.total, style: AppTextStyles.cartItemName),
                      ),
                      Text(
                        CurrencyFormatter.format(data.expenseTotalMmk),
                        style: AppTextStyles.cartItemName,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    ReportRange current,
  ) async {
    final now = ShopDateUtils.nowInShop();
    final initialStart = current.customFromYmd != null
        ? DateTime.parse(current.customFromYmd!)
        : DateTime(now.year, now.month, now.day);
    final initialEnd = current.customToYmd != null
        ? DateTime.parse(current.customToYmd!)
        : DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked == null) return;
    final from =
        '${picked.start.year.toString().padLeft(4, '0')}-'
        '${picked.start.month.toString().padLeft(2, '0')}-'
        '${picked.start.day.toString().padLeft(2, '0')}';
    final to =
        '${picked.end.year.toString().padLeft(4, '0')}-'
        '${picked.end.month.toString().padLeft(2, '0')}-'
        '${picked.end.day.toString().padLeft(2, '0')}';
    ref.read(reportRangeProvider.notifier).state = ReportRange.custom(
      fromYmd: from,
      toYmd: to,
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.cartItemName),
        ],
      ),
    );
  }
}
