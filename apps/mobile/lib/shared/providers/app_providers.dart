import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../core/auth/auth_constants.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/device_id_service.dart';
import '../../core/auth/pin_service.dart';
import '../../core/auth/token_cache.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_cursor.dart';
import '../../core/sync/sync_flusher.dart';
import '../../core/sync/sync_pull_applier.dart';
import '../../core/sync/sync_puller.dart';
import '../../core/sync/sync_rejection_handler.dart';
import '../../core/sync/sync_runtime.dart';
import '../../core/utils/uuid_generator.dart';

const kDeviceNameKey = 'g9pos_device_name';
const kDefaultDeviceName = 'G9POS';

/// Overridden in `main()` and in tests. Never opens a file from the default.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('appDatabaseProvider must be overridden');
});

final appLoggerProvider = Provider<Logger>((ref) => Logger());

final uuidGeneratorProvider = Provider<UuidGenerator>((ref) => UuidGenerator());

final nowMsProvider = Provider<int Function()>((ref) {
  return () => DateTime.now().millisecondsSinceEpoch;
});

class DeviceNameNotifier extends StateNotifier<String> {
  DeviceNameNotifier(this._storage) : super(kDefaultDeviceName) {
    _restore();
  }

  final FlutterSecureStorage _storage;

  Future<void> _restore() async {
    final saved = await _storage.read(key: kDeviceNameKey);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
    }
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: kDeviceNameKey, value: trimmed);
    state = trimmed;
  }
}

final deviceNameNotifierProvider =
    StateNotifierProvider<DeviceNameNotifier, String>((ref) {
  return DeviceNameNotifier(const FlutterSecureStorage());
});

final deviceNameProvider = Provider<String>((ref) {
  return ref.watch(deviceNameNotifierProvider);
});

/// Ticks once a minute so sync-age colors in the header stay current.
final clockTickProvider = StreamProvider<int>((ref) async* {
  yield DateTime.now().millisecondsSinceEpoch;
  yield* Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now().millisecondsSinceEpoch,
  );
});

final deviceTypeProvider = Provider<String>((ref) => 'tablet');

final apiUrlProvider = Provider<String>((ref) => kApiUrl);

final tokenCacheProvider = Provider<TokenCache>((ref) => TokenCache());

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    tokens: ref.watch(tokenCacheProvider),
    deviceIds: ref.watch(deviceIdServiceProvider),
    deviceName: ref.watch(deviceNameProvider),
    deviceType: ref.watch(deviceTypeProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final pinServiceProvider = Provider<PinService>((ref) {
  return PinService(
    db: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final syncNoticeStoreProvider = Provider<SyncNoticeStore>((ref) {
  return SyncNoticeStore();
});

final syncRejectionHandlerProvider = Provider<SyncRejectionHandler>((ref) {
  return SyncRejectionHandler(
    db: ref.watch(appDatabaseProvider),
    notices: ref.watch(syncNoticeStoreProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final syncFlusherProvider = Provider<SyncFlusher>((ref) {
  final tokens = ref.watch(tokenCacheProvider);
  return SyncFlusher(
    db: ref.watch(appDatabaseProvider),
    rejectionHandler: ref.watch(syncRejectionHandlerProvider),
    accessToken: tokens.getAccessToken,
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});

final syncCursorProvider = Provider<SyncCursor>((ref) => SyncCursor());

final lastSyncAtMsProvider = StateProvider<int?>((ref) => null);

final syncPullerProvider = Provider<SyncPuller>((ref) {
  final tokens = ref.watch(tokenCacheProvider);
  final devices = ref.watch(deviceIdServiceProvider);
  return SyncPuller(
    applier: SyncPullApplier(
      db: ref.watch(appDatabaseProvider),
      logger: ref.watch(appLoggerProvider),
      nowMs: ref.watch(nowMsProvider),
    ),
    cursor: ref.watch(syncCursorProvider),
    accessToken: tokens.getAccessToken,
    accessTokenValid: tokens.isAccessTokenValid,
    refresh: () => ref.read(authServiceProvider).refreshToken(),
    deviceId: devices.getOrCreateDeviceId,
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
    onCursor: (ms) {
      ref.read(lastSyncAtMsProvider.notifier).state = ms == 0 ? null : ms;
    },
  );
});

final syncRuntimeProvider = Provider<SyncRuntime>((ref) {
  final runtime = SyncRuntime(
    flusher: ref.watch(syncFlusherProvider),
    puller: ref.watch(syncPullerProvider),
    logger: ref.watch(appLoggerProvider),
  );
  runtime.start();
  ref.onDispose(runtime.dispose);
  return runtime;
});

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).syncQueueDao.watchPendingCount();
});

final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  List<ConnectivityResult> current;
  try {
    current = await connectivity.checkConnectivity();
  } catch (_) {
    yield true;
    return;
  }
  yield current.any((r) => r != ConnectivityResult.none);
  await for (final results in connectivity.onConnectivityChanged) {
    yield results.any((r) => r != ConnectivityResult.none);
  }
});
