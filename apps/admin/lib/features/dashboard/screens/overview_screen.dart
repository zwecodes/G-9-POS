import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../providers/dashboard_providers.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => EmptyState(
        icon: Icons.error_outline,
        message: error is ApiException
            ? error.message
            : 'Could not load the dashboard. Try again.',
      ),
      data: (data) {
        final money = NumberFormat('#,###').format(data.revenueMmk);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(overviewProvider);
            await ref.read(overviewProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
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
