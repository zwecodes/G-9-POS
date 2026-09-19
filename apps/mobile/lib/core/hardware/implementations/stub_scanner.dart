import 'dart:async';

import '../hardware_constants.dart';
import '../hardware_status.dart';
import '../interfaces/scanner_interface.dart';

/// Always disconnected until a real Bluetooth HID implementation is wired.
/// Manual barcode entry and future HID scans both publish to [onBarcodeScanned].
class StubScanner implements ScannerInterface {
  final _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get onBarcodeScanned => _controller.stream;

  @override
  bool get isConnected => false;

  @override
  HardwareConnectionStatus get status => HardwareConnectionStatus.disconnected;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}

  /// Manual entry and HID paths converge here (§4.4).
  void submitBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;
    _controller.add(trimmed);
  }

  void dispose() {
    _controller.close();
  }
}

/// Skeleton for the real Netum/Eyoyo HID path — not used until hardware arrives.
/// Keeps the scan-vs-type threshold in one place (§4.2).
class BluetoothHidScannerSkeleton {
  BluetoothHidScannerSkeleton({
    required void Function(String barcode) onScan,
    this.thresholdMs = HardwareConstants.scanThresholdMs,
  }) : _onScan = onScan;

  final void Function(String barcode) _onScan;
  final int thresholdMs;
  final _buffer = StringBuffer();
  Timer? _debounce;

  void onKeyInput(String char) {
    if (char == '\n' || char == '\r') {
      _flush();
      return;
    }
    _buffer.write(char);
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: thresholdMs), _flush);
  }

  void _flush() {
    _debounce?.cancel();
    final result = _buffer.toString().trim();
    _buffer.clear();
    if (result.isNotEmpty) _onScan(result);
  }

  void dispose() {
    _debounce?.cancel();
  }
}
