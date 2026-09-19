import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hardware_status.dart';
import 'implementations/bluetooth_hid_scanner.dart';
import 'implementations/niimbot_printer.dart';
import 'implementations/receipt_printer_factory.dart';
import 'interfaces/label_printer_interface.dart';
import 'interfaces/receipt_printer_interface.dart';
import 'interfaces/scanner_interface.dart';

final scannerProvider = Provider<ScannerInterface>((ref) {
  final scanner = BluetoothHIDScanner();
  ref.onDispose(scanner.dispose);
  return scanner;
});

final receiptPrinterProvider = Provider<ReceiptPrinterInterface>((ref) {
  final created = createReceiptPrinter();
  ref.onDispose(created.dispose);
  return created.printer;
});

final labelPrinterProvider = Provider<LabelPrinterInterface>((ref) {
  return NiimbotPrinter();
});

final scannerStatusProvider = Provider<HardwareConnectionStatus>((ref) {
  return ref.watch(scannerProvider).status;
});

final printerStatusProvider = Provider<HardwareConnectionStatus>((ref) {
  return ref.watch(receiptPrinterProvider).status;
});

/// True when the sale screen should show the manual barcode field (§4.4).
final showManualBarcodeEntryProvider = Provider<bool>((ref) {
  return !ref.watch(scannerProvider).isConnected;
});
