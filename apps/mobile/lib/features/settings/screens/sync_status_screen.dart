import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/ui_primitives.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final lastSync = ref.watch(lastSyncAtMsProvider);
    final notices = ref.watch(syncNoticeStoreProvider).items;
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
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Sync now',
            onPressed: () async {
              await ref.read(syncFlusherProvider).flush();
              ref.read(lastSyncAtMsProvider.notifier).state =
                  DateTime.now().millisecondsSinceEpoch;
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
}
