import '../hardware_status.dart';
import '../interfaces/label_printer_interface.dart';

/// Post-launch NIIMBOT B21 stub — HARDWARE-INTEGRATION.md §6.
class NiimbotPrinter implements LabelPrinterInterface {
  @override
  bool get isConnected => false;

  @override
  HardwareConnectionStatus get status => HardwareConnectionStatus.disconnected;

  @override
  Future<bool> connect() async {
    throw UnimplementedError(
      'NiimbotPrinter is post-launch — label printing is not available in v1.',
    );
  }

  @override
  Future<void> disconnect() async {}
}
