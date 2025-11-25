import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/database_providers.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final supabaseSyncServiceProvider = Provider<SupabaseSyncService?>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (supabase == null || userId == null) {
    return null;
  }

  final repository = ref.watch(localDatabaseRepositoryProvider);
  final connectivity = ref.watch(connectivityProvider);

  final service = SupabaseSyncService(
    client: supabase.client,
    repository: repository,
    connectivity: connectivity,
  );

  ref.onDispose(service.dispose);
  return service;
});
