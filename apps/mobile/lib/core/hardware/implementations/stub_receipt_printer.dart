import '../hardware_status.dart';
import '../interfaces/receipt_printer_interface.dart';

/// Always disconnected — sale completion must not wait on this.
class StubReceiptPrinter implements ReceiptPrinterInterface {
  @override
  bool get isConnected => false;

  @override
  HardwareConnectionStatus get status => HardwareConnectionStatus.disconnected;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrintResult> printReceipt(ReceiptData data) async {
    return PrintResult.disconnected;
  }
}
