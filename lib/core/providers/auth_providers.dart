import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';

final authServiceProvider = ChangeNotifierProvider<AuthService?>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  if (supabase == null) {
    // Return null if Supabase is not configured
    return null;
  }
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
  // In debug mode, return null (we'll use DEBUG_UID directly)
  // The actual session is not needed in debug mode
  if (kDebugMode) {
    const debugUid = String.fromEnvironment('DEBUG_UID');
    if (debugUid.isNotEmpty) {
      return null; // We use DEBUG_UID directly, not session
    }
  }
  
  final authService = ref.watch(authServiceProvider);
  return authService?.state.session;
});

final currentUserIdProvider = Provider<String?>((ref) {
  // In debug mode, use DEBUG_UID from environment if available
  if (kDebugMode) {
    const debugUid = String.fromEnvironment('DEBUG_UID');
    if (debugUid.isNotEmpty) {
      return debugUid;
    }
  }
  
  final session = ref.watch(authSessionProvider);
  return session?.user.id;
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  // In debug mode, use DEBUG_UID from environment to simulate authenticated state
  if (kDebugMode) {
    const debugUid = String.fromEnvironment('DEBUG_UID');
    if (debugUid.isNotEmpty) {
      return AuthStatus.authenticated;
    }
  }
  
  final authService = ref.watch(authServiceProvider);
  return authService?.state.status ?? AuthStatus.unauthenticated;
});

final magicLinkSentProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService?.state.magicLinkSent ?? false;
});

final authErrorMessageProvider = Provider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService?.state.errorMessage;
});
