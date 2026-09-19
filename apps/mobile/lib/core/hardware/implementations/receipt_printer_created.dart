import '../interfaces/receipt_printer_interface.dart';

class CreatedReceiptPrinter {
  const CreatedReceiptPrinter({
    required this.printer,
    required this.dispose,
  });

  final ReceiptPrinterInterface printer;
  final void Function() dispose;
}
