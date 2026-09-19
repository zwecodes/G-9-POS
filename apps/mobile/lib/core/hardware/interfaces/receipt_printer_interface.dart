import '../hardware_status.dart';

enum PrintResult {
  success,
  timeout,
  disconnected,
  paperOut,
  unknown,
}

/// Built from the local sale record after checkout — never blocks the sale.
class ReceiptData {
  const ReceiptData({
    required this.saleNumber,
    required this.totalAmountMmk,
    required this.lines,
    this.shopName = 'G9POS',
    this.shopSubtitle = 'Pin Laung Motorcycle Parts',
    this.paymentMethod = 'cash',
    this.createdAtMs,
  });

  final String saleNumber;
  final int totalAmountMmk;
  final List<ReceiptLine> lines;
  final String shopName;
  final String shopSubtitle;
  final String paymentMethod;
  final int? createdAtMs;
}

class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.subtotalMmk,
  });

  final String name;
  final int quantity;
  final int subtotalMmk;
}

abstract class ReceiptPrinterInterface {
  Future<PrintResult> printReceipt(ReceiptData data);

  Future<bool> connect();

  Future<void> disconnect();

  bool get isConnected;

  HardwareConnectionStatus get status;
}
