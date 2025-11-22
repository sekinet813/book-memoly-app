import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/services/supabase_service.dart';
import 'features/search/search_feature.dart';

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

class BookMemolyApp extends StatelessWidget {
  const BookMemolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Memoly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SearchPage(),
    );
  }
}
