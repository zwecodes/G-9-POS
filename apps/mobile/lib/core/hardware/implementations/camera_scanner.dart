import 'dart:async';

import '../hardware_status.dart';
import '../interfaces/scanner_interface.dart';

/// Post-launch camera barcode scanner (`mobile_scanner`) — HARDWARE-INTEGRATION.md §7.
class CameraScanner implements ScannerInterface {
  final _controller = StreamController<String>.broadcast();

  @override
  Stream<String> get onBarcodeScanned => _controller.stream;

  @override
  bool get isConnected => false;

  @override
  HardwareConnectionStatus get status => HardwareConnectionStatus.disconnected;

  @override
  Future<bool> connect() async {
    throw UnimplementedError(
      'CameraScanner is post-launch — use Bluetooth HID or manual entry for v1.',
    );
  }

  @override
  Future<void> disconnect() async {}

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
