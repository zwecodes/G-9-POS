import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'shared/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: G9posAdminApp()));
}

class G9posAdminApp extends ConsumerWidget {
  const G9posAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'G9POS Dashboard',
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
