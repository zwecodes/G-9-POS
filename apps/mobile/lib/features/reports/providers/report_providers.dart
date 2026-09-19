import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/app_providers.dart';
import '../repositories/report_repository.dart';

enum ReportPeriod { today, thisWeek, custom }

class ReportRange {
  const ReportRange({
    required this.period,
    required this.startMs,
    required this.endMs,
    this.customFromYmd,
    this.customToYmd,
  });

  final ReportPeriod period;
  final int startMs;
  final int endMs;
  final String? customFromYmd;
  final String? customToYmd;

  factory ReportRange.today() {
    final range = ShopDateUtils.todayRangeMs();
    return ReportRange(
      period: ReportPeriod.today,
      startMs: range.$1,
      endMs: range.$2,
    );
  }

  factory ReportRange.thisWeek() {
    final range = ShopDateUtils.thisWeekRangeMs();
    return ReportRange(
      period: ReportPeriod.thisWeek,
      startMs: range.$1,
      endMs: range.$2,
    );
  }

  factory ReportRange.custom({
    required String fromYmd,
    required String toYmd,
  }) {
    final range = ShopDateUtils.rangeFromShopDates(
      fromYmd: fromYmd,
      toYmd: toYmd,
    );
    return ReportRange(
      period: ReportPeriod.custom,
      startMs: range.$1,
      endMs: range.$2,
      customFromYmd: fromYmd,
      customToYmd: toYmd,
    );
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(db: ref.watch(appDatabaseProvider));
});

final reportRangeProvider =
    StateProvider<ReportRange>((ref) => ReportRange.today());

final reportSummaryProvider = FutureProvider<DailyReportSummary>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportRepositoryProvider).summarizeRange(
        startMsInclusive: range.startMs,
        endMsExclusive: range.endMs,
      );
});
