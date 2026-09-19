import '../hardware_status.dart';

/// NIIMBOT / label printing — post-launch. Stub only for v1.
abstract class LabelPrinterInterface {
  Future<bool> connect();

  Future<void> disconnect();

  bool get isConnected;

  HardwareConnectionStatus get status;
}
