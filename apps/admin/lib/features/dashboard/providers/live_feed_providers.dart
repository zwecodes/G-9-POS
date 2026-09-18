import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/live/live_feed_client.dart';
import '../../../shared/providers/app_providers.dart';
import 'dashboard_providers.dart';

export '../../../core/live/live_feed_client.dart'
    show LiveFeedState, LiveSaleItem;

final liveFeedClientProvider = Provider<LiveFeedClient>((ref) {
  final client = LiveFeedClient(
    apiBaseUrl: kApiUrl,
    store: ref.watch(sessionStoreProvider),
  );
  ref.onDispose(client.stop);
  return client;
});

class LiveFeedNotifier extends StateNotifier<LiveFeedState> {
  LiveFeedNotifier(this._client, this._ref) : super(const LiveFeedState()) {
    _client.onConnectionChanged = (connected) {
      if (!mounted) return;
      state = state.copyWith(connected: connected);
    };
    _client.onEvent = _handleEvent;
  }

  final LiveFeedClient _client;
  final Ref _ref;

  Future<void> start() => _client.start();

  Future<void> stop() async {
    await _client.stop();
    if (!mounted) return;
    state = const LiveFeedState();
  }

  void _handleEvent(String event, Map<String, dynamic> payload) {
    switch (event) {
      case 'sale.created':
        _onSaleCreated(payload);
        break;
      case 'sale.voided':
        _onSaleVoided(payload);
        break;
      case 'stock.low':
        _onStockNotice(payload, low: true);
        break;
      case 'stock.negative':
        _onStockNotice(payload, low: false);
        break;
      case 'device.sync_status':
      case 'device.activated':
        _ref.invalidate(overviewProvider);
        _ref.invalidate(devicesProvider);
        break;
      default:
        break;
    }
  }

  void _onSaleCreated(Map<String, dynamic> payload) {
    final saleRaw = payload['sale'];
    if (saleRaw is! Map<String, dynamic>) return;
    final item = LiveSaleItem(
      id: saleRaw['id'] as String? ?? '',
      saleNumber: saleRaw['sale_number'] as String? ?? '',
      totalAmountMmk: (saleRaw['total_amount_mmk'] as num?)?.toInt() ?? 0,
      createdAtMs: (saleRaw['created_at'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
    if (item.id.isEmpty) return;
    final next = [
      item,
      ...state.recentSales.where((s) => s.id != item.id),
    ];
    state = state.copyWith(recentSales: next.take(20).toList());
    _ref.invalidate(overviewProvider);
    _ref.invalidate(salesProvider);
  }

  void _onSaleVoided(Map<String, dynamic> payload) {
    final saleId = payload['sale_id'] as String?;
    if (saleId != null) {
      state = state.copyWith(
        recentSales: state.recentSales
            .where((s) => s.id != saleId)
            .toList(growable: false),
        notices: [
          'A sale was voided on the shop device.',
          ...state.notices,
        ].take(10).toList(),
      );
    }
    _ref.invalidate(overviewProvider);
    _ref.invalidate(salesProvider);
  }

  void _onStockNotice(Map<String, dynamic> payload, {required bool low}) {
    final stock = payload['computed_stock'];
    final message = low
        ? 'A product is low on stock (now $stock).'
        : 'A product has negative stock (now $stock).';
    state = state.copyWith(
      notices: [message, ...state.notices].take(10).toList(),
    );
    _ref.invalidate(overviewProvider);
  }
}

final liveFeedProvider =
    StateNotifierProvider<LiveFeedNotifier, LiveFeedState>((ref) {
  final notifier = LiveFeedNotifier(ref.watch(liveFeedClientProvider), ref);
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    if (next.signedIn && !(previous?.signedIn ?? false)) {
      notifier.start();
    } else if (!next.signedIn && (previous?.signedIn ?? false)) {
      notifier.stop();
    }
  });
  final session = ref.read(sessionProvider);
  if (session.signedIn) {
    Future.microtask(notifier.start);
  }
  return notifier;
});
