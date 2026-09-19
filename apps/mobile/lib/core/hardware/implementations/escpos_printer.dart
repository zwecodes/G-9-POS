import 'dart:async';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:logger/logger.dart';

import '../../utils/currency_formatter.dart';
import '../../utils/date_utils.dart';
import '../hardware_constants.dart';
import '../hardware_status.dart';
import '../interfaces/receipt_printer_interface.dart';

/// ESC/POS receipt printer over Bluetooth SPP (GOOJPRT PT-210 / Xprinter XP-P300).
///
/// Android-only. Off Android, [connect] returns false and [printReceipt] returns
/// [PrintResult.disconnected] — never throws to callers (§5.3).
class EscPosPrinter implements ReceiptPrinterInterface {
  EscPosPrinter({Logger? logger}) : _log = logger ?? Logger();

  final Logger _log;

  BluetoothConnection? _connection;
  bool _connected = false;
  DateTime? _lastJobAt;
  bool _jobInFlight = false;

  static bool get isPlatformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get isConnected =>
      _connected && (_connection?.isConnected ?? false);

  @override
  HardwareConnectionStatus get status => isConnected
      ? HardwareConnectionStatus.connected
      : HardwareConnectionStatus.disconnected;

  @override
  Future<bool> connect() async {
    if (!isPlatformSupported) return false;
    try {
      final enabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (enabled != true) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      final bonded =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      if (bonded.isEmpty) return false;

      final preferred = bonded.where((d) => _looksLikePrinter(d.name)).toList();
      final candidates = preferred.isNotEmpty ? preferred : bonded;

      for (final device in candidates) {
        try {
          await _connection?.close();
        } catch (_) {}
        _connection = null;
        _connected = false;

        try {
          final connection = await BluetoothConnection.toAddress(device.address)
              .timeout(
            Duration(seconds: kPrinterSendTimeoutSeconds),
          );
          _connection = connection;
          _connected = true;
          connection.input?.listen(
            (_) {},
            onDone: () {
              _connected = false;
              _connection = null;
            },
            onError: (_) {
              _connected = false;
              _connection = null;
            },
            cancelOnError: true,
          );
          return true;
        } catch (e, st) {
          _log.w('Printer connect failed for ${device.name}', error: e, stackTrace: st);
        }
      }
      return false;
    } catch (e, st) {
      _log.w('Printer connect failed', error: e, stackTrace: st);
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _connection?.close();
    } catch (e, st) {
      _log.w('Printer disconnect failed', error: e, stackTrace: st);
    } finally {
      _connection = null;
      _connected = false;
    }
  }

  @override
  Future<PrintResult> printReceipt(ReceiptData data) async {
    try {
      if (!isPlatformSupported) return PrintResult.disconnected;
      if (!isConnected || _connection == null) {
        return PrintResult.disconnected;
      }
      if (_jobInFlight) {
        // Never send two jobs at once (§5.5) — caller can reprint later.
        return PrintResult.unknown;
      }

      final sinceLast = _lastJobAt == null
          ? null
          : DateTime.now().difference(_lastJobAt!);
      if (sinceLast != null &&
          sinceLast.inMilliseconds < kPrinterJobIntervalMs) {
        await Future<void>.delayed(
          Duration(milliseconds: kPrinterJobIntervalMs - sinceLast.inMilliseconds),
        );
      }

      _jobInFlight = true;
      final bytes = await _buildReceiptBytes(data);
      final connection = _connection;
      if (connection == null || !connection.isConnected) {
        return PrintResult.disconnected;
      }

      connection.output.add(Uint8List.fromList(bytes));
      await connection.output.allSent.timeout(
        Duration(seconds: kPrinterSendTimeoutSeconds),
      );
      _lastJobAt = DateTime.now();
      return PrintResult.success;
    } on TimeoutException {
      return PrintResult.timeout;
    } catch (e, st) {
      _log.w('Print failed', error: e, stackTrace: st);
      if (!isConnected) return PrintResult.disconnected;
      return PrintResult.unknown;
    } finally {
      _jobInFlight = false;
    }
  }

  Future<List<int>> _buildReceiptBytes(ReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final List<int> bytes = [];

    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(
      '=' * 32,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      'G9POS RECEIPT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.text(
      data.shopSubtitle,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      '=' * 32,
      styles: const PosStyles(align: PosAlign.center),
    ));

    final whenMs = data.createdAtMs ?? ShopDateUtils.nowInShop().millisecondsSinceEpoch;
    final when = ShopDateUtils.fromUnixMs(whenMs);
    final dateStr = '${when.year.toString().padLeft(4, '0')}-'
        '${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    bytes.addAll(generator.text('Date: $dateStr  Time: $timeStr'));
    bytes.addAll(generator.text('Sale: ${data.saleNumber}'));
    bytes.addAll(generator.text('-' * 32));

    for (final line in data.lines) {
      final qty = 'x${line.quantity}';
      bytes.addAll(generator.text(_truncate('${line.name}  $qty', 32)));
      bytes.addAll(generator.text(
        CurrencyFormatter.format(line.subtotalMmk),
        styles: const PosStyles(align: PosAlign.right),
      ));
    }

    bytes.addAll(generator.text('-' * 32));
    bytes.addAll(generator.text(
      'TOTAL: ${CurrencyFormatter.format(data.totalAmountMmk)}',
      styles: const PosStyles(bold: true),
    ));
    bytes.addAll(generator.text(
      'PAYMENT: ${data.paymentMethod.toUpperCase()}',
    ));
    bytes.addAll(generator.text('-' * 32));
    bytes.addAll(generator.text(
      'Thank you for shopping!',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      '=' * 32,
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static bool _looksLikePrinter(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final n = name.toLowerCase();
    return n.contains('print') ||
        n.contains('pt-') ||
        n.contains('pt_') ||
        n.contains('xp-') ||
        n.contains('xp_') ||
        n.contains('goojprt') ||
        n.contains('xprinter') ||
        n.contains('pos58') ||
        n.contains('pos-') ||
        n.contains('thermal');
  }

  static String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  void dispose() {
    unawaited(disconnect());
  }
}
