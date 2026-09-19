import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/providers/auth_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../settings/providers/device_settings_providers.dart';
import '../providers/setup_providers.dart';

/// Guided first-run checklist (HARDWARE-INTEGRATION.md §5.8 / REQUIREMENTS.md).
class FirstRunSetupScreen extends ConsumerStatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  ConsumerState<FirstRunSetupScreen> createState() =>
      _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends ConsumerState<FirstRunSetupScreen> {
  final _deviceName = TextEditingController();
  var _syncing = false;
  var _activating = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deviceName.text = ref.read(deviceNameNotifierProvider);
    });
  }

  @override
  void dispose() {
    _deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final checklist = ref.watch(setupChecklistProvider);
    final products = ref.watch(productListProvider).valueOrNull ?? [];
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';

    if (!checklist.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setupTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.setupIntro,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.setupDeviceName, style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _deviceName,
            decoration: InputDecoration(
              labelText: l10n.setupDeviceNameHint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: l10n.saveName,
            onPressed: isOwner ? _saveName : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.setupHardware, style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          _ChecklistTile(
            title: l10n.setupScannerTitle,
            subtitle: l10n.setupScannerSubtitle,
            mark: checklist.scanner,
            onDone: () => ref
                .read(setupChecklistProvider.notifier)
                .setScanner(ChecklistMark.done),
            onSkip: () => ref
                .read(setupChecklistProvider.notifier)
                .setScanner(ChecklistMark.skipped),
          ),
          _ChecklistTile(
            title: l10n.setupPrinterTitle,
            subtitle: l10n.setupPrinterSubtitle,
            mark: checklist.printer,
            onDone: () => ref
                .read(setupChecklistProvider.notifier)
                .setPrinter(ChecklistMark.done),
            onSkip: () => ref
                .read(setupChecklistProvider.notifier)
                .setPrinter(ChecklistMark.skipped),
          ),
          _ChecklistTile(
            title: l10n.setupOtherTitle,
            subtitle: l10n.setupOtherSubtitle,
            mark: checklist.otherDevice,
            onDone: () => ref
                .read(setupChecklistProvider.notifier)
                .setOtherDevice(ChecklistMark.done),
            onSkip: () => ref
                .read(setupChecklistProvider.notifier)
                .setOtherDevice(ChecklistMark.skipped),
          ),
          TextButton(
            onPressed: () => context.push('/settings/hardware'),
            child: Text(
              l10n.openHardwareStatus,
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.setupSync, style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          Text(
            products.isEmpty
                ? l10n.setupSyncEmpty
                : l10n.setupSyncReady(products.length, pending),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: l10n.syncNow,
            busy: _syncing,
            onPressed: _syncing ? null : _syncNow,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.setupActivePos, style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.setupActivePosHelp,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: l10n.makeActivePos,
            busy: _activating,
            onPressed: (!isOwner || _activating) ? null : _activate,
          ),
          ErrorText(_error),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _message!,
              style: AppTextStyles.body.copyWith(color: AppColors.success),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.finishSetup,
            onPressed: checklist.canFinish ? _finish : null,
          ),
          if (!checklist.canFinish)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.finishSetupHint,
                style: AppTextStyles.caption,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _message = null;
    });
    final name = _deviceName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.enterDeviceName);
      return;
    }
    try {
      await ref.read(deviceSettingsRepositoryProvider).renameThisDevice(name);
      await ref.read(deviceNameNotifierProvider.notifier).setName(name);
      if (!mounted) return;
      setState(() => _message = l10n.deviceNameSaved);
    } catch (_) {
      // Offline rename fails — still keep the local display name.
      await ref.read(deviceNameNotifierProvider.notifier).setName(name);
      if (!mounted) return;
      setState(() => _message = l10n.nameSavedLocal);
    }
  }

  Future<void> _syncNow() async {
    final l10n = context.l10n;
    setState(() {
      _syncing = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(syncRuntimeProvider).syncNow();
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _message = l10n.syncFinished;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = l10n.couldNotSync;
      });
    }
  }

  Future<void> _activate() async {
    final l10n = context.l10n;
    setState(() {
      _activating = true;
      _error = null;
      _message = null;
    });
    try {
      await ref.read(deviceSettingsRepositoryProvider).activateThisDevice();
      if (!mounted) return;
      setState(() {
        _activating = false;
        _message = l10n.activePosQueued;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = 'Could not activate this device. Try again from Settings.';
      });
    }
  }

  Future<void> _finish() async {
    await ref.read(setupChecklistProvider.notifier).markComplete();
    if (!mounted) return;
    context.go('/pos');
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.subtitle,
    required this.mark,
    required this.onDone,
    required this.onSkip,
  });

  final String title;
  final String subtitle;
  final ChecklistMark mark;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = switch (mark) {
      ChecklistMark.done => (l10n.done, AppColors.success),
      ChecklistMark.skipped => (l10n.skipped, AppColors.warning),
      ChecklistMark.pending => (l10n.needed, AppColors.textMuted),
    };
    return Card(
      elevation: 0,
      color: AppColors.surfaceVariant,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.cartItemName)),
                Text(
                  status.$1,
                  style: AppTextStyles.caption.copyWith(color: status.$2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: onDone,
                  child: Text(
                    l10n.done,
                    style: AppTextStyles.body.copyWith(color: AppColors.success),
                  ),
                ),
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    l10n.skip,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
