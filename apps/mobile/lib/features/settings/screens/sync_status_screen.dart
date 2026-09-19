import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/ui_primitives.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final lastSync = ref.watch(lastSyncAtMsProvider);
    final notices = ref.watch(syncNoticeStoreProvider).items;
    final ageLine = _stalenessLine(lastSync);
    return Scaffold(
      appBar: AppBar(title: const Text('Sync status')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Pending items: $pending', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text(
            lastSync == null
                ? 'Not synced yet'
                : 'Last synced ${ShopDateUtils.formatShopDateTime(lastSync)}',
            style: AppTextStyles.caption,
          ),
          if (ageLine != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ageLine.$1,
              style: AppTextStyles.body.copyWith(color: ageLine.$2),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Sync now',
            onPressed: () async {
              await ref.read(syncRuntimeProvider).syncNow();
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('Notices', style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          if (notices.isEmpty)
            const Text('No sync problems.', style: AppTextStyles.caption)
          else
            for (final notice in notices)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(notice.message, style: AppTextStyles.body),
              ),
        ],
      ),
    );
  }

  (String, Color)? _stalenessLine(int? lastSync) {
    if (lastSync == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - lastSync;
    if (age > 24 * 60 * 60 * 1000) {
      return (
        'Sync is more than a day old. Connect to the internet when you can.',
        AppColors.error,
      );
    }
    if (age > 4 * 60 * 60 * 1000) {
      final hours = (age / (60 * 60 * 1000)).floor();
      return (
        'Last sync was about ${hours}h ago. Still safe to sell.',
        AppColors.stale,
      );
    }
    if (age > 2 * 60 * 60 * 1000) {
      return (
        'Sync is a few hours old. Still safe to sell.',
        AppColors.warning,
      );
    }
    return null;
  }
}
