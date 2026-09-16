import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _comma = NumberFormat('#,###', 'en_US');

  static String format(int amountMmk) => '${_comma.format(amountMmk)} MMK';

  static String formatCompact(int amountMmk) => _comma.format(amountMmk);
}
