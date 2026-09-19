import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/hardware_provider.dart';
import '../../../core/hardware/implementations/bluetooth_hid_scanner.dart';

/// Invisible focus sink for Bluetooth HID keystrokes when the scanner is connected.
/// Does not block sales — only routes characters into [BluetoothHIDScanner.onKeyInput].
class HidScannerFocus extends ConsumerStatefulWidget {
  const HidScannerFocus({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HidScannerFocus> createState() => _HidScannerFocusState();
}

class _HidScannerFocusState extends ConsumerState<HidScannerFocus> {
  final _focus = FocusNode(debugLabel: 'hidScanner');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final scanner = ref.read(scannerProvider);
    if (scanner is! BluetoothHIDScanner || !scanner.isConnected) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
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

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(scannerProvider).isConnected;
    if (connected && !_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focus.hasFocus) {
          _focus.requestFocus();
        }
      });
    }
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      canRequestFocus: connected,
      child: widget.child,
    );
  }
}
