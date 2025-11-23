import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  runApp(
    ProviderScope(
      overrides: [supabaseServiceProvider.overrideWithValue(supabaseService)],
      child: const BookMemolyApp(),
    ),
  );
}

class BookMemolyApp extends ConsumerWidget {
  const BookMemolyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Book Memoly',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
