import '../hardware_status.dart';
import '../interfaces/label_printer_interface.dart';

/// Post-launch NIIMBOT stub.
class StubLabelPrinter implements LabelPrinterInterface {
  @override
  bool get isConnected => false;

  @override
  HardwareConnectionStatus get status => HardwareConnectionStatus.disconnected;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}
}
