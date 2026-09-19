import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/hardware_provider.dart';
import '../../../core/hardware/implementations/stub_scanner.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/barcode_listener_provider.dart';

/// Visible when no scanner is connected — HARDWARE-INTEGRATION.md §4.4.
class ManualBarcodeField extends ConsumerStatefulWidget {
  const ManualBarcodeField({super.key});

  @override
  ConsumerState<ManualBarcodeField> createState() => _ManualBarcodeFieldState();
}

class _ManualBarcodeFieldState extends ConsumerState<ManualBarcodeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = ref.watch(showManualBarcodeEntryProvider);
    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Barcode',
                prefixIcon: Icon(Icons.keyboard),
                hintText: 'Type barcode and press Enter',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: AppSpacing.minTapTarget,
            width: AppSpacing.minTapTarget + AppSpacing.md,
            child: IconButton(
              tooltip: 'Add by barcode',
              onPressed: _submit,
              icon: const Icon(Icons.add_shopping_cart),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      ref.read(barcodeLookupErrorProvider.notifier).state = 'Enter a barcode.';
      return;
    }
    ref.read(barcodeLookupErrorProvider.notifier).state = null;
    final scanner = ref.read(scannerProvider);
    if (scanner is StubScanner) {
      scanner.submitBarcode(raw);
    }
    _controller.clear();
    _focus.requestFocus();
  }
}
