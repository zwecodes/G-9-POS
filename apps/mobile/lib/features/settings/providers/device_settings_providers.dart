import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../repositories/device_settings_repository.dart';

final deviceSettingsRepositoryProvider =
    Provider<DeviceSettingsRepository>((ref) {
  return DeviceSettingsRepository(
    db: ref.watch(appDatabaseProvider),
    identity: ref.watch(appIdentityProvider),
    tokens: ref.watch(tokenCacheProvider),
    apiUrl: ref.watch(apiUrlProvider),
    uuids: ref.watch(uuidGeneratorProvider),
    logger: ref.watch(appLoggerProvider),
    nowMs: ref.watch(nowMsProvider),
  );
});
