import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'core/database/connection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'shared/providers/app_providers.dart';
import 'shared/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final db = openFileDatabase();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const G9PosApp(),
    ),
  );
}

class G9PosApp extends ConsumerWidget {
  const G9PosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncRuntimeProvider);
    ref.listen(isOnlineProvider, (previous, next) {
      next.whenData((online) {
        if (online) ref.read(syncRuntimeProvider).onOnline();
      });
    });
    ref.listen(sessionProvider, (previous, next) {
      if (next.hasJwt && previous?.hasJwt != true) {
        ref.read(syncRuntimeProvider).onOnline();
      }
    });
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'G9POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
