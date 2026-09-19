import '../hardware_status.dart';

/// Bluetooth HID barcode scanner — HARDWARE-INTEGRATION.md §3–§4.
abstract class ScannerInterface {
  Stream<String> get onBarcodeScanned;

  Future<bool> connect();

  Future<void> disconnect();

  bool get isConnected;

  HardwareConnectionStatus get status;
}
