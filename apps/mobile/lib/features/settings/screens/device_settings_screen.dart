import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/providers/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/device_settings_providers.dart';

class DeviceSettingsScreen extends ConsumerStatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  ConsumerState<DeviceSettingsScreen> createState() =>
      _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  late final TextEditingController _name;
  String? _error;
  String? _success;
  var _savingName = false;
  var _activating = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _name.text = ref.read(deviceNameNotifierProvider);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(sessionProvider).operatorRole == 'owner';
    final deviceId = ref.watch(appIdentityProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('This device'),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: !isOwner
                ? const EmptyState(
                    icon: Icons.lock_outline,
                    message: 'Only the owner can change device settings.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      FutureBuilder<String>(
                        future: deviceId.deviceId,
                        builder: (context, snapshot) {
                          final id = snapshot.data ?? '…';
                          return Text(
                            'Device ID: $id',
                            style: AppTextStyles.caption,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Device name *',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Save name',
                        busy: _savingName,
                        onPressed: _savingName ? null : _saveName,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'Active POS',
                        style: AppTextStyles.sectionHeader,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Mark this tablet or phone as the shop’s active POS. '
                        'Works offline — it syncs when the internet returns.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Make this the active POS',
                        busy: _activating,
                        onPressed: _activating ? null : _activate,
                      ),
                      ErrorText(_error),
                      if (_success != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _success!,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    setState(() {
      _savingName = true;
      _error = null;
      _success = null;
    });
    try {
      final name = _name.text.trim();
      await ref.read(deviceSettingsRepositoryProvider).renameThisDevice(name);
      await ref.read(deviceNameNotifierProvider.notifier).setName(name);
      if (!mounted) return;
      setState(() {
        _savingName = false;
        _success = 'Device name saved.';
      });
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _savingName = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingName = false;
        _error =
            'Could not rename this device. Check the connection and try again.';
      });
    }
  }

  Future<void> _activate() async {
    setState(() {
      _activating = true;
      _error = null;
      _success = null;
    });
    try {
      await ref.read(deviceSettingsRepositoryProvider).activateThisDevice();
      if (!mounted) return;
      setState(() {
        _activating = false;
        _success =
            'This device will be the active POS after the next successful sync.';
      });
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = 'Could not make this the active POS. Try again.';
      });
    }
  }
}
