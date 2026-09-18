import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class ShopDateUtils {
  ShopDateUtils._();

  static const shopTimezone = 'Asia/Yangon';

  static tz.Location get _location => tz.getLocation(shopTimezone);

  static tz.TZDateTime nowInShop() => tz.TZDateTime.now(_location);

  static tz.TZDateTime fromUnixMs(int unixMs) {
    final utc = DateTime.fromMillisecondsSinceEpoch(unixMs, isUtc: true);
    return tz.TZDateTime.from(utc, _location);
  }

  static String shopDateString(DateTime utc) {
    final local = tz.TZDateTime.from(utc.toUtc(), _location);
    return DateFormat('yyyy-MM-dd').format(local);
  }

  static bool isSameShopDay(DateTime a, DateTime b) =>
      shopDateString(a) == shopDateString(b);

  static String formatShopTime(int unixMs) {
    return DateFormat('HH:mm').format(fromUnixMs(unixMs));
  }

  static String formatShopDateTime(int unixMs) {
    return DateFormat('yyyy-MM-dd HH:mm').format(fromUnixMs(unixMs));
  }

  /// Calendar day in the shop timezone — for `expense_date` / void day checks.
  static String todayShopDateString() =>
      DateFormat('yyyy-MM-dd').format(nowInShop());
}
