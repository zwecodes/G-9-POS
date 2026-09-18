import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/dashboard_providers.dart';
import '../providers/live_feed_providers.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the socket alive while the shell is open.
    ref.watch(liveFeedProvider);
    final overview = ref.watch(overviewProvider);
    final live = ref.watch(liveFeedProvider);
    final moneyFmt = NumberFormat('#,###');

    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => EmptyState(
        icon: Icons.error_outline,
        message: error is ApiException
            ? error.message
            : 'Could not load the dashboard. Try again.',
      ),
      data: (data) {
        final money = moneyFmt.format(data.revenueMmk);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(overviewProvider);
            await ref.read(overviewProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: AppSpacing.sm,
                    color: live.connected
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    live.connected
                        ? 'Live updates connected'
                        : 'Live updates reconnecting…',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Shop day ${data.date}', style: AppTextStyles.sectionHeader),
              const SizedBox(height: AppSpacing.sm),
              Text('$money MMK', style: AppTextStyles.saleTotal),
              const SizedBox(height: AppSpacing.xs),
              const Text("Today's revenue", style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xl),
              _StatTile(
                label: 'Low stock products',
                value: '${data.lowStockCount}',
                color: data.lowStockCount > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              _StatTile(
                label: 'Active POS',
                value: data.activeDevice?.name ?? 'None active',
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Live sales', style: AppTextStyles.sectionHeader),
              const SizedBox(height: AppSpacing.sm),
              if (live.recentSales.isEmpty)
                Text(
                  'New sales from the shop will appear here when online.',
                  style: AppTextStyles.caption,
                )
              else
                for (final sale in live.recentSales)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sale.saleNumber, style: AppTextStyles.body),
                    subtitle: Text(
                      DateFormat('HH:mm:ss').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          sale.createdAtMs,
                          isUtc: true,
                        ).toLocal(),
                      ),
                      style: AppTextStyles.caption,
                    ),
                    trailing: Text(
                      '${moneyFmt.format(sale.totalAmountMmk)} MMK',
                      style: AppTextStyles.body,
                    ),
                  ),
              if (live.notices.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const Text('Alerts', style: AppTextStyles.sectionHeader),
                const SizedBox(height: AppSpacing.sm),
                for (final notice in live.notices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      notice,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Text('Devices', style: AppTextStyles.sectionHeader),
              const SizedBox(height: AppSpacing.sm),
              if (data.devices.isEmpty)
                Text(
                  'No devices registered yet.',
                  style: AppTextStyles.caption,
                )
              else
                for (final device in data.devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(device.name, style: AppTextStyles.body),
                    subtitle: Text(
                      [
                        device.type,
                        if (device.isActivePos) 'active POS',
                        if (device.revokedAtMs != null) 'revoked',
                        if (device.lastSyncAtMs != null)
                          'last sync ${DateTime.fromMillisecondsSinceEpoch(device.lastSyncAtMs!).toUtc()}',
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.title.copyWith(color: color)),
        ],
      ),
    );
  }
}
