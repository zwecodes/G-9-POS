import 'dart:async';

import 'package:logger/logger.dart';

import 'sync_flusher.dart';
import 'sync_puller.dart';

/// Background flush + pull. Never invoked from checkout.
class SyncRuntime {
  SyncRuntime({
    required SyncFlusher flusher,
    required SyncPuller puller,
    required bool Function() hasJwt,
    Logger? logger,
    Duration interval = const Duration(seconds: 60),
  })  : _flusher = flusher,
        _puller = puller,
        _hasJwt = hasJwt,
        _log = logger ?? Logger(),
        _interval = interval;

  final SyncFlusher _flusher;
  final SyncPuller _puller;
  final bool Function() _hasJwt;
  final Logger _log;
  final Duration _interval;

  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(_interval, (_) {
      unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  void onOnline() {
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (!_hasJwt()) return;
    try {
      await _flusher.flush();
      await _puller.pull();
    } catch (error, stack) {
      _log.e('Background sync failed', error: error, stackTrace: stack);
    }
  }

  void dispose() {
    _timer?.cancel();
    _flusher.dispose();
  }
}
