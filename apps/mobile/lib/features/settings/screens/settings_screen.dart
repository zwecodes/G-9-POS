import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_status.dart';
import '../../auth/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(l10n.language, style: AppTextStyles.sectionHeader),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'my',
                        label: Text(l10n.languageMyanmar),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(l10n.languageEnglish),
                      ),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (values) {
                      ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(values.first));
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.salesHistory, style: AppTextStyles.body),
                  onTap: () => context.push('/settings/sales'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.expenses, style: AppTextStyles.body),
                  onTap: () => context.push('/settings/expenses'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.categories, style: AppTextStyles.body),
                  onTap: () => context.push('/settings/categories'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.thisDevice, style: AppTextStyles.body),
                  onTap: () => context.push('/settings/device'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    l10n.deviceSetupChecklist,
                    style: AppTextStyles.body,
                  ),
                  onTap: () => context.push('/setup'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.syncStatus, style: AppTextStyles.body),
                  onTap: () => context.go('/settings/sync'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.hardware, style: AppTextStyles.body),
                  onTap: () => context.push('/settings/hardware'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    session.operatorName ?? l10n.signedIn,
                    style: AppTextStyles.caption,
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.changePin, style: AppTextStyles.body),
                  onTap: () => context.push('/settings/pin'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(l10n.lockScreen, style: AppTextStyles.body),
                  onTap: () => ref.read(sessionProvider.notifier).lock(),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    l10n.signOut,
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final d = dialogContext.l10n;
        return AlertDialog(
          title: Text(d.signOutConfirmTitle, style: AppTextStyles.title),
          content: Text(d.signOutConfirmBody, style: AppTextStyles.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                d.stay,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                d.signOut,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await ref.read(sessionProvider.notifier).signOut();
    }
  }
}
