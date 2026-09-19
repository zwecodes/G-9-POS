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

  /// Start of a shop calendar day as UTC epoch ms (inclusive).
  static int startOfShopDayMs(tz.TZDateTime day) {
    final start = tz.TZDateTime(_location, day.year, day.month, day.day);
    return start.millisecondsSinceEpoch;
  }

  /// Exclusive end of a shop calendar day as UTC epoch ms.
  static int endOfShopDayMs(tz.TZDateTime day) {
    final end = tz.TZDateTime(_location, day.year, day.month, day.day + 1);
    return end.millisecondsSinceEpoch;
  }

  /// Monday 00:00 of the shop week containing [day].
  static tz.TZDateTime startOfShopWeek(tz.TZDateTime day) {
    final weekday = day.weekday; // Mon=1 … Sun=7
    final monday = day.subtract(Duration(days: weekday - 1));
    return tz.TZDateTime(_location, monday.year, monday.month, monday.day);
  }

  static (int startMs, int endMs) todayRangeMs() {
    final now = nowInShop();
    return (startOfShopDayMs(now), endOfShopDayMs(now));
  }

  static (int startMs, int endMs) thisWeekRangeMs() {
    final now = nowInShop();
    final start = startOfShopWeek(now);
    return (start.millisecondsSinceEpoch, endOfShopDayMs(now));
  }

  /// Inclusive shop-date strings `yyyy-MM-dd` → ms range [start, end).
  static (int startMs, int endMs) rangeFromShopDates({
    required String fromYmd,
    required String toYmd,
  }) {
    final from = DateTime.parse(fromYmd);
    final to = DateTime.parse(toYmd);
    final fromLocal = tz.TZDateTime(_location, from.year, from.month, from.day);
    final toLocal = tz.TZDateTime(_location, to.year, to.month, to.day);
    return (startOfShopDayMs(fromLocal), endOfShopDayMs(toLocal));
  }
}
