import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'escpos_printer.dart';
import 'receipt_printer_created.dart';
import 'stub_receipt_printer.dart';

export 'receipt_printer_created.dart';

/// Android uses real ESC/POS; other IO platforms stay on the stub.
CreatedReceiptPrinter createReceiptPrinter() {
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (android) {
    final printer = EscPosPrinter();
    return CreatedReceiptPrinter(
      printer: printer,
      dispose: printer.dispose,
    );
  }
  return CreatedReceiptPrinter(
    printer: StubReceiptPrinter(),
    dispose: () {},
  );
}
