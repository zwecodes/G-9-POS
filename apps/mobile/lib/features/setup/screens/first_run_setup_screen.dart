import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        title: const Text('Set up this device'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Complete these steps before the shop opens. You can skip optional '
            'items, but do not skip them on both devices.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('1. Device name', style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _deviceName,
            decoration: const InputDecoration(
              labelText: 'Name (e.g. Counter tablet)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Save name',
            onPressed: isOwner ? _saveName : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('2. Hardware checklist', style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          _ChecklistTile(
            title: 'Barcode scanner paired to this device',
            subtitle: 'Pair in Android Bluetooth settings, then confirm here.',
            mark: checklist.scanner,
            onDone: () => ref
                .read(setupChecklistProvider.notifier)
                .setScanner(ChecklistMark.done),
            onSkip: () => ref
                .read(setupChecklistProvider.notifier)
                .setScanner(ChecklistMark.skipped),
          ),
          _ChecklistTile(
            title: 'Receipt printer paired to this device',
            subtitle: 'Optional at launch — skip if you have no printer yet.',
            mark: checklist.printer,
            onDone: () => ref
                .read(setupChecklistProvider.notifier)
                .setPrinter(ChecklistMark.done),
            onSkip: () => ref
                .read(setupChecklistProvider.notifier)
                .setPrinter(ChecklistMark.skipped),
          ),
          _ChecklistTile(
            title: 'Other device (tablet or phone) also set up',
            subtitle:
                'Both devices must be paired and signed in before opening day.',
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
              'Open hardware status',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('3. Sync catalog', style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          Text(
            products.isEmpty
                ? 'No products on this device yet. Sync now after the catalog '
                    'was imported on the dashboard.'
                : '${products.length} products ready. Pending sync: $pending.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Sync now',
            busy: _syncing,
            onPressed: _syncing ? null : _syncNow,
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('4. Active POS', style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mark this device as the shop’s active POS, or skip if this is the '
            'standby phone.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Make this the active POS',
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
            label: 'Finish setup',
            onPressed: checklist.canFinish ? _finish : null,
          ),
          if (!checklist.canFinish)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Mark or skip every checklist item before finishing.',
                style: AppTextStyles.caption,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    setState(() {
      _error = null;
      _message = null;
    });
    final name = _deviceName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a device name.');
      return;
    }
    try {
      await ref.read(deviceSettingsRepositoryProvider).renameThisDevice(name);
      await ref.read(deviceNameNotifierProvider.notifier).setName(name);
      if (!mounted) return;
      setState(() => _message = 'Device name saved.');
    } catch (_) {
      // Offline rename fails — still keep the local display name.
      await ref.read(deviceNameNotifierProvider.notifier).setName(name);
      if (!mounted) return;
      setState(
        () => _message =
            'Name saved on this device. It will update on the server when online.',
      );
    }
  }

  Future<void> _syncNow() async {
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
        _message = 'Sync finished.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error =
            'Could not sync. Check the connection and try again — you can still finish setup.';
      });
    }
  }

  Future<void> _activate() async {
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
        _message =
            'This device will be the active POS after the next successful sync.';
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
    final status = switch (mark) {
      ChecklistMark.done => ('Done', AppColors.success),
      ChecklistMark.skipped => ('Skipped', AppColors.warning),
      ChecklistMark.pending => ('Needed', AppColors.textMuted),
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
                    'Done',
                    style: AppTextStyles.body.copyWith(color: AppColors.success),
                  ),
                ),
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
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
