import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

class TopProductRow {
  const TopProductRow({
    required this.productId,
    required this.name,
    required this.quantitySold,
  });

  final String productId;
  final String name;
  final int quantitySold;
}

class ExpenseSummaryRow {
  const ExpenseSummaryRow({
    required this.category,
    required this.amountMmk,
  });

  final String category;
  final int amountMmk;
}

class DailyReportSummary {
  const DailyReportSummary({
    required this.revenueMmk,
    required this.profitMmk,
    required this.incompleteProfit,
    required this.saleCount,
    required this.itemsSold,
    required this.topProducts,
    required this.expenses,
    required this.expenseTotalMmk,
  });

  final int revenueMmk;
  final int? profitMmk;
  final bool incompleteProfit;
  final int saleCount;
  final int itemsSold;
  final List<TopProductRow> topProducts;
  final List<ExpenseSummaryRow> expenses;
  final int expenseTotalMmk;
}

/// Offline daily summary from local SQLite (SHOP_TIMEZONE).
class ReportRepository {
  ReportRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<DailyReportSummary> summarizeRange({
    required int startMsInclusive,
    required int endMsExclusive,
  }) async {
    final allSales = await _db.saleDao.getAll();
    final sales = allSales
        .where(
          (s) =>
              s.status == 'completed' &&
              s.createdAt >= startMsInclusive &&
              s.createdAt < endMsExclusive,
        )
        .toList();

    var revenue = 0;
    for (final sale in sales) {
      revenue += sale.totalAmountMmk;
    }

    final saleIds = sales.map((s) => s.id).toSet();
    final items = saleIds.isEmpty
        ? <SaleItem>[]
        : await (_db.select(_db.saleItems)
              ..where((i) => i.saleId.isIn(saleIds)))
            .get();

    var itemsSold = 0;
    final qtyByProduct = <String, int>{};
    final nameByProduct = <String, String>{};
    for (final item in items) {
      itemsSold += item.quantity;
      qtyByProduct[item.productId] =
          (qtyByProduct[item.productId] ?? 0) + item.quantity;
      nameByProduct[item.productId] = item.productNameSnapshot;
    }

    final top = qtyByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = top
        .take(5)
        .map(
          (e) => TopProductRow(
            productId: e.key,
            name: nameByProduct[e.key] ?? e.key,
            quantitySold: e.value,
          ),
        )
        .toList();

    var incompleteProfit = false;
    var profit = 0;
    if (items.isNotEmpty) {
      final productIds = items.map((i) => i.productId).toSet().toList();
      final products = await (_db.select(_db.products)
            ..where((p) => p.id.isIn(productIds)))
          .get();
      final costById = {
        for (final p in products) p.id: p.costPriceMmk,
      };
      for (final item in items) {
        final cost = costById[item.productId];
        if (cost == null) {
          incompleteProfit = true;
          continue;
        }
        profit += (item.priceSnapshotMmk - cost) * item.quantity;
      }
    }

    final fromDate = ShopDateUtils.shopDateString(
      DateTime.fromMillisecondsSinceEpoch(startMsInclusive, isUtc: true),
    );
    final toDateInclusive = ShopDateUtils.shopDateString(
      DateTime.fromMillisecondsSinceEpoch(endMsExclusive - 1, isUtc: true),
    );

    final allExpenses = await _db.expenseDao.getAllActive();
    final expenses = allExpenses
        .where(
          (e) =>
              e.expenseDate.compareTo(fromDate) >= 0 &&
              e.expenseDate.compareTo(toDateInclusive) <= 0,
        )
        .toList();

    final byCategory = <String, int>{};
    var expenseTotal = 0;
    for (final expense in expenses) {
      expenseTotal += expense.amountMmk;
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0) + expense.amountMmk;
    }
    final expenseRows = byCategory.entries
        .map((e) => ExpenseSummaryRow(category: e.key, amountMmk: e.value))
        .toList()
      ..sort((a, b) => b.amountMmk.compareTo(a.amountMmk));

    return DailyReportSummary(
      revenueMmk: revenue,
      profitMmk: incompleteProfit ? null : profit,
      incompleteProfit: incompleteProfit,
      saleCount: sales.length,
      itemsSold: itemsSold,
      topProducts: topProducts,
      expenses: expenseRows,
      expenseTotalMmk: expenseTotal,
    );
  }
}
