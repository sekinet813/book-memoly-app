import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/services/supabase_service.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseService? supabaseService;
  try {
    supabaseService = SupabaseService();
    await supabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    debugPrint('App will continue without Supabase support.');
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

class BookMemolyApp extends StatelessWidget {
  const BookMemolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Book Memoly',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
