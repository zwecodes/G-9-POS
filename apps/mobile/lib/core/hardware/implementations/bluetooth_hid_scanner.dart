import 'dart:async';

import '../hardware_constants.dart';
import '../hardware_status.dart';
import '../interfaces/scanner_interface.dart';

/// Bluetooth HID barcode scanner (Netum NT-1228BL / Eyoyo EY-015).
///
/// Pairing is OS-level; [connect] marks the app ready to accept HID keystrokes.
/// Scan-vs-type: characters within [kScanThresholdMs] emit as one barcode (§4.2).
class BluetoothHIDScanner implements ScannerInterface {
  BluetoothHIDScanner({this.thresholdMs = kScanThresholdMs});

  final int thresholdMs;

  final _controller = StreamController<String>.broadcast();
  final _buffer = StringBuffer();
  Timer? _debounce;
  bool _connected = false;

  @override
  Stream<String> get onBarcodeScanned => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  HardwareConnectionStatus get status => _connected
      ? HardwareConnectionStatus.connected
      : HardwareConnectionStatus.disconnected;

  /// HID pairing lives in Android Bluetooth settings — always succeeds in-app.
  @override
  Future<bool> connect() async {
    _connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// Called from a focused key listener when the HID scanner types characters.
  void onKeyInput(String char) {
    if (char == '\n' || char == '\r') {
      _flush();
      return;
    }
    _buffer.write(char);
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: thresholdMs), _flush);
  }

  /// Manual entry and HID paths converge here (§4.4).
  void submitBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;
    _controller.add(trimmed);
  }

  void _flush() {
    _debounce?.cancel();
    _debounce = null;
    final result = _buffer.toString().trim();
    _buffer.clear();
    if (result.isNotEmpty) {
      _controller.add(result);
    }
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _buffer.clear();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
