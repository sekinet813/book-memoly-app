import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/routing/app_router.dart';
import 'core/providers/settings_providers.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/theme.dart';
import 'core/providers/notification_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ja');

  SupabaseService? supabaseService;
  try {
    final service = SupabaseService();
    await service.initialize();
    supabaseService = service;
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    debugPrint('App will continue without Supabase support.');
    supabaseService = null;
  }

  runApp(
    ProviderScope(
      overrides: supabaseService != null
          ? [supabaseServiceProvider.overrideWithValue(supabaseService)]
          : [],
      child: const BookMemolyApp(),
    ),
  );
}

class BookMemolyApp extends ConsumerWidget {
  const BookMemolyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Setup notification navigation handler
    ref.watch(notificationNavigationProvider);

    final router = ref.watch(appRouterProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Book Memoly',
      theme: AppTheme.lightTheme(fontScale),
      darkTheme: AppTheme.darkTheme(fontScale),
      themeMode: themeMode.toMaterialThemeMode(),
      routerConfig: router,
    );
  }
}
