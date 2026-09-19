import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_ext.dart';
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
    final l10n = context.l10n;
    ref.watch(clockTickProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final lastSync = ref.watch(lastSyncAtMsProvider);
    final notices = ref.watch(syncNoticeStoreProvider).items;
    final ageLine = _stalenessLine(context, lastSync);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncStatus)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.pendingItems(pending), style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text(
            lastSync == null
                ? l10n.notSyncedYet
                : l10n.lastSynced(ShopDateUtils.formatShopDateTime(lastSync)),
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
            label: l10n.syncNow,
            onPressed: () async {
              await ref.read(syncRuntimeProvider).syncNow();
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.notices, style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          if (notices.isEmpty)
            Text(l10n.noSyncProblems, style: AppTextStyles.caption)
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

  (String, Color)? _stalenessLine(BuildContext context, int? lastSync) {
    if (lastSync == null) return null;
    final l10n = context.l10n;
    final age = DateTime.now().millisecondsSinceEpoch - lastSync;
    if (age > 24 * 60 * 60 * 1000) {
      return (l10n.syncStaleDay, AppColors.error);
    }
    if (age > 4 * 60 * 60 * 1000) {
      final hours = (age / (60 * 60 * 1000)).floor();
      return (l10n.syncStaleHours(hours), AppColors.stale);
    }
    if (age > 2 * 60 * 60 * 1000) {
      return (l10n.syncStaleFewHours, AppColors.warning);
    }
    return null;
  }
}
