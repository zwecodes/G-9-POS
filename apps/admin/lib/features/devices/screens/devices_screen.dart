import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../dashboard/repositories/dashboard_repository.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Devices', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Revoke a lost phone or tablet so it cannot sync or refresh '
                'tokens. The device keeps working offline until it next reaches '
                'the server.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              ErrorText(_error),
            ],
          ),
        ),
        Expanded(
          child: devices.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => EmptyState(
              icon: Icons.error_outline,
              message: error is ApiException
                  ? error.message
                  : 'Could not load devices. Try again.',
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.phone_android_outlined,
                  message: 'No devices registered yet.',
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = list[index];
                  final revoked = device.revokedAtMs != null;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    title: Text(device.name, style: AppTextStyles.body),
                    subtitle: Text(
                      [
                        device.type,
                        if (device.isActivePos) 'active POS',
                        if (revoked) 'revoked',
                        if (device.lastSyncAtMs != null)
                          'last sync ${_fmt(device.lastSyncAtMs!)}',
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                    trailing: revoked
                        ? Text(
                            'Revoked',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
                            ),
                          )
                        : TextButton(
                            onPressed: () => _confirmRevoke(device),
                            child: Text(
                              'Revoke',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmt(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmRevoke(DeviceSummary device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revoke this device?', style: AppTextStyles.title),
          content: Text(
            '${device.name} will need the owner password to sign in again '
            'after it next connects.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Revoke',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(dashboardRepositoryProvider).revokeDevice(device.id);
      ref.invalidate(devicesProvider);
      ref.invalidate(overviewProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not revoke the device. Try again.');
    }
  }
}
