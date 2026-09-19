import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/app_providers.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();
    return Container(
      height: AppSpacing.offlineBanner,
      width: double.infinity,
      color: AppColors.warning,
      alignment: Alignment.center,
      child: Text(
        context.l10n.offlineBanner,
        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(clockTickProvider);
    final lastSync = ref.watch(lastSyncAtMsProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var color = AppColors.success;
    String? label;
    if (lastSync == null) {
      color = pending > 0 ? AppColors.warning : AppColors.success;
    } else {
      final age = now - lastSync;
      if (age > 24 * 60 * 60 * 1000) {
        color = AppColors.error;
        label = l10n.ago1d;
      } else if (age > 4 * 60 * 60 * 1000) {
        color = AppColors.stale;
        label = l10n.agoHours((age / (60 * 60 * 1000)).floor());
      } else if (age > 2 * 60 * 60 * 1000) {
        color = AppColors.warning;
      }
    }

    return IconButton(
      tooltip: l10n.syncStatus,
      iconSize: AppSpacing.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      onPressed: () => context.go('/settings/sync'),
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done, color: color, size: AppSpacing.lg),
          if (label != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTextStyles.caption.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}
