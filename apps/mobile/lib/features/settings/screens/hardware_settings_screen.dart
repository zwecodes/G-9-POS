import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/hardware_provider.dart';
import '../../../core/hardware/hardware_status.dart';
import '../../../core/hardware/implementations/bluetooth_hid_scanner.dart';
import '../../../core/hardware/interfaces/receipt_printer_interface.dart';
import '../../../core/l10n/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_status.dart';

/// Pair devices in OS Bluetooth settings, then verify with Test Scanner / Test Printer.
class HardwareSettingsScreen extends ConsumerStatefulWidget {
  const HardwareSettingsScreen({super.key});

  @override
  ConsumerState<HardwareSettingsScreen> createState() =>
      _HardwareSettingsScreenState();
}

class _HardwareSettingsScreenState
    extends ConsumerState<HardwareSettingsScreen> {
  bool _testingScanner = false;
  bool _testingPrinter = false;
  StreamSubscription<String>? _scanSub;
  final _hidFocus = FocusNode();

  @override
  void dispose() {
    _scanSub?.cancel();
    _hidFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onHidKey(FocusNode node, KeyEvent event) {
    if (!_testingScanner) return KeyEventResult.ignored;
    final scanner = ref.read(scannerProvider);
    if (scanner is! BluetoothHIDScanner) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      scanner.onKeyInput('\n');
      return KeyEventResult.handled;
    }
    final label = event.character;
    if (label != null && label.isNotEmpty) {
      scanner.onKeyInput(label);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _testScanner() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testingScanner = true);
    await _scanSub?.cancel();
    _scanSub = null;

    try {
      final scanner = ref.read(scannerProvider);
      final ok = await scanner.connect();
      if (!mounted) return;
      setState(() {});
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scannerTestFailed)));
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.scannerTestWaiting)),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hidFocus.requestFocus();
      });

      final completer = Completer<String>();
      _scanSub = scanner.onBarcodeScanned.listen((code) {
        if (!completer.isCompleted) completer.complete(code);
      });

      final code = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => '',
      );
      if (!mounted) return;
      if (code.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scannerTestFailed)));
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.scannerTestSuccess(code))),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scannerTestFailed)));
      }
    } finally {
      await _scanSub?.cancel();
      _scanSub = null;
      if (mounted) setState(() => _testingScanner = false);
    }
  }

  Future<void> _testPrinter() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testingPrinter = true);

    try {
      final printer = ref.read(receiptPrinterProvider);
      final ok = await printer.connect();
      if (!mounted) return;
      setState(() {});
      if (!ok || !printer.isConnected) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.printerTestDisconnected)),
        );
        return;
      }

      final result = await printer.printReceipt(
        ReceiptData(
          saleNumber: 'TEST',
          totalAmountMmk: 0,
          lines: const [
            ReceiptLine(name: 'Test print', quantity: 1, subtotalMmk: 0),
          ],
          paymentMethod: 'cash',
        ),
      );

      if (!mounted) return;
      final message = switch (result) {
        PrintResult.success => l10n.printerTestSuccess,
        PrintResult.disconnected => l10n.printerTestDisconnected,
        PrintResult.timeout => l10n.printerTestTimeout,
        PrintResult.paperOut => l10n.printerTestPaperOut,
        PrintResult.unknown => l10n.printerTestFailed,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.printerTestFailed)));
      }
    } finally {
      if (mounted) setState(() => _testingPrinter = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scanner = ref.watch(scannerProvider);
    final printer = ref.watch(receiptPrinterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hardwareTitle)),
      body: Focus(
        focusNode: _hidFocus,
        onKeyEvent: _onHidKey,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    l10n.hardwareHelp,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.barcodeScanner, style: AppTextStyles.body),
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
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.minTapTarget,
                    child: FilledButton(
                      onPressed: _testingScanner ? null : _testScanner,
                      child: Text(
                        _testingScanner
                            ? l10n.scannerTestWaiting
                            : l10n.testScanner,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.receiptPrinter, style: AppTextStyles.body),
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
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.minTapTarget,
                    child: FilledButton(
                      onPressed: _testingPrinter ? null : _testPrinter,
                      child: Text(
                        _testingPrinter
                            ? l10n.hardwareConnecting
                            : l10n.testPrinter,
                      ),
                    ),
                  ),
                  if (scanner is BluetoothHIDScanner) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.hardwareHidHint,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
