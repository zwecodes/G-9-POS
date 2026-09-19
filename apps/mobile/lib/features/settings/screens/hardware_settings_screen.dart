import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/hardware_provider.dart';
import '../../../core/hardware/hardware_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_status.dart';

/// Status-only until real Bluetooth drivers are plugged in.
class HardwareSettingsScreen extends ConsumerWidget {
  const HardwareSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanner = ref.watch(scannerProvider);
    final printer = ref.watch(receiptPrinterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hardware')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Scanner and printer are not connected yet. Sales still work '
                  '— type barcodes manually and reprint receipts from history '
                  'after you pair hardware.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Barcode scanner', style: AppTextStyles.body),
                  subtitle: Text(
                    scanner.status.label,
                    style: AppTextStyles.caption,
                  ),
                  trailing: Icon(
                    scanner.isConnected
                        ? Icons.check_circle
                        : Icons.highlight_off,
                    color: scanner.isConnected
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Receipt printer', style: AppTextStyles.body),
                  subtitle: Text(
                    printer.status.label,
                    style: AppTextStyles.caption,
                  ),
                  trailing: Icon(
                    printer.isConnected
                        ? Icons.check_circle
                        : Icons.highlight_off,
                    color: printer.isConnected
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Test buttons will appear here after Bluetooth pairing is added.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
