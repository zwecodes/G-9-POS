import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/utils/date_utils.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('shop day range is exclusive at the next midnight in Asia/Yangon', () {
    final loc = tz.getLocation('Asia/Yangon');
    final day = tz.TZDateTime(loc, 2026, 9, 18, 15, 30);
    final start = ShopDateUtils.startOfShopDayMs(day);
    final end = ShopDateUtils.endOfShopDayMs(day);

    expect(
      ShopDateUtils.fromUnixMs(start).toString(),
      contains('2026-09-18 00:00:00'),
    );
    expect(
      ShopDateUtils.fromUnixMs(end).toString(),
      contains('2026-09-19 00:00:00'),
    );
    expect(end - start, 24 * 60 * 60 * 1000);
  });

  test('rangeFromShopDates is inclusive on both calendar days', () {
    final range = ShopDateUtils.rangeFromShopDates(
      fromYmd: '2026-09-17',
      toYmd: '2026-09-18',
    );
    expect(range.$2 - range.$1, 2 * 24 * 60 * 60 * 1000);
  });
}
