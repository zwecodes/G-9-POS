import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/hardware_provider.dart';
import '../../../core/hardware/hardware_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Non-blocking scanner/printer indicators — never disable sale actions.
class HardwareStatusBar extends ConsumerWidget {
  const HardwareStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanner = ref.watch(scannerStatusProvider);
    final printer = ref.watch(printerStatusProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _Chip(
            icon: Icons.qr_code_scanner,
            label: 'Scanner: ${scanner.label}',
            ready: scanner.isReady,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Chip(
            icon: Icons.print_outlined,
            label: 'Printer: ${printer.label}',
            ready: printer.isReady,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.ready,
  });

  final IconData icon;
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.md, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
