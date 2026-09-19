import 'receipt_printer_created.dart';
import 'receipt_printer_factory_stub.dart'
    if (dart.library.io) 'receipt_printer_factory_io.dart' as impl;

export 'receipt_printer_created.dart';

/// Platform-aware receipt printer construction.
///
/// Web uses the stub factory. IO platforms use Android ESC/POS when available.
CreatedReceiptPrinter createReceiptPrinter() => impl.createReceiptPrinter();
