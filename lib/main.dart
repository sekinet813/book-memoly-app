import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/routing/app_router.dart';
import 'core/providers/settings_providers.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/theme.dart';
import 'core/providers/notification_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[main] ✅ Loaded .env file');
  } catch (e) {
    debugPrint('[main] ⚠️ Failed to load .env file: $e');
    debugPrint('[main] Continuing without .env file...');
  }

  await initializeDateFormatting('ja');

  SupabaseService? supabaseService;
  try {
    final service = SupabaseService();
    await service.initialize();
    supabaseService = service;
    debugPrint('[main] Supabase service initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('[main] ❌ Supabase initialization failed: $e');
    debugPrint('[main] Stack trace: $stackTrace');
    debugPrint('[main] App will continue without Supabase support.');
    debugPrint('[main] To fix this:');
    debugPrint('[main]   1. Create a .env file in the project root');
    debugPrint('[main]   2. Add SUPABASE_URL and SUPABASE_ANON_KEY');
    debugPrint('[main]   3. Run the app using: ./run.sh');
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
