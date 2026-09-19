import 'receipt_printer_created.dart';
import 'stub_receipt_printer.dart';

export 'receipt_printer_created.dart';

/// Non-Android / desktop: no Bluetooth SPP.
CreatedReceiptPrinter createReceiptPrinter() {
  return CreatedReceiptPrinter(
    printer: StubReceiptPrinter(),
    dispose: () {},
  );
}
