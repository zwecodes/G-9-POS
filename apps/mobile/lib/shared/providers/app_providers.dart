import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../core/auth/auth_constants.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/device_id_service.dart';
import '../../core/auth/pin_service.dart';
import '../../core/auth/token_cache.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_flusher.dart';
import '../../core/sync/sync_rejection_handler.dart';
import '../../core/utils/uuid_generator.dart';

/// Overridden in `main()` and in tests. Never opens a file from the default.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('appDatabaseProvider must be overridden');
});

final appLoggerProvider = Provider<Logger>((ref) => Logger());

final uuidGeneratorProvider = Provider<UuidGenerator>((ref) => UuidGenerator());

final nowMsProvider = Provider<int Function()>((ref) {
  return () => DateTime.now().millisecondsSinceEpoch;
});

final deviceNameProvider = Provider<String>((ref) => 'G9POS');

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
