import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/utils/date_utils.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';
import 'package:g9pos/features/reports/repositories/report_repository.dart';
import 'package:g9pos/features/sales/repositories/sale_repository.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(() {
    silenceLoggers();
    tzdata.initializeTimeZones();
  });

  test('daily summary uses completed sales and flags incomplete profit', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final withCost = await repos.products.create(
      const ProductDraft(
        name: 'Filter',
        priceMmk: 10000,
        costPriceMmk: 6000,
      ),
    );
    final noCost = await repos.products.create(
      const ProductDraft(name: 'Glove', priceMmk: 4000),
    );

    await repos.sales.completeSale(
      lines: [
        SaleLineInput(
          productId: withCost.id,
          productNameSnapshot: 'Filter',
          priceSnapshotMmk: 10000,
          quantity: 2,
        ),
        SaleLineInput(
          productId: noCost.id,
          productNameSnapshot: 'Glove',
          priceSnapshotMmk: 4000,
          quantity: 1,
        ),
      ],
    );

    final range = ShopDateUtils.todayRangeMs();
    final summary = await ReportRepository(db: repos.db).summarizeRange(
      startMsInclusive: range.$1,
      endMsExclusive: range.$2,
    );

    expect(summary.saleCount, 1);
    expect(summary.revenueMmk, 24000);
    expect(summary.itemsSold, 3);
    expect(summary.incompleteProfit, isTrue);
    expect(summary.profitMmk, isNull);
    expect(summary.topProducts.first.name, 'Filter');
    expect(summary.topProducts.first.quantitySold, 2);
  });

  test('profit is shown when every sold product has a cost price', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(
        name: 'Oil',
        priceMmk: 10000,
        costPriceMmk: 7000,
      ),
    );
    await repos.sales.completeSale(
      lines: [
        SaleLineInput(
          productId: product.id,
          productNameSnapshot: 'Oil',
          priceSnapshotMmk: 10000,
          quantity: 3,
        ),
      ],
    );

    final range = ShopDateUtils.todayRangeMs();
    final summary = await ReportRepository(db: repos.db).summarizeRange(
      startMsInclusive: range.$1,
      endMsExclusive: range.$2,
    );

    expect(summary.incompleteProfit, isFalse);
    expect(summary.profitMmk, 9000);
  });
}
