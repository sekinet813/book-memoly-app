import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';

final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final service = AuthService(
    client: supabase.client,
    config: supabase.config,
  );

  ref.onDispose(service.dispose);
  // Initialize after first frame to allow Supabase to be ready.
  service.initialize();

  return service;
});

final authSessionProvider = Provider<Session?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.state.session;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider);
  return session?.user.id;
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.state.status;
});

final magicLinkSentProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.state.magicLinkSent;
});

final authErrorMessageProvider = Provider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.state.errorMessage;
});
