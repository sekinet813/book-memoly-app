import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/config/supabase_config.dart';

final supabaseServiceProvider = Provider<SupabaseService?>((ref) {
  // Return null if not overridden, allowing the app to work without Supabase
  return null;
});

class SupabaseService {
  SupabaseService({SupabaseConfig? config})
      : _config = config ?? SupabaseConfig.fromEnvironment();

  final SupabaseConfig _config;

  Future<void> initialize() async {
    if (!_config.isValid) {
      final missing = <String>[];
      if (_config.supabaseUrl.trim().isEmpty) {
        missing.add('SUPABASE_URL');
      }
      if (_config.supabaseAnonKey.trim().isEmpty) {
        missing.add('SUPABASE_ANON_KEY');
      }
      throw StateError(
        'Supabase configuration missing: ${missing.join(', ')}. '
        'Please set these values in .env file and run the app using ./run.sh',
      );
    }

    debugPrint('[SupabaseService] Initializing Supabase...');
    debugPrint('[SupabaseService] URL: ${_config.supabaseUrl.substring(0, _config.supabaseUrl.length > 30 ? 30 : _config.supabaseUrl.length)}...');
    debugPrint('[SupabaseService] Redirect URL: ${_config.authRedirectUrl ?? 'not set (using default)'}');

    try {
      await Supabase.initialize(
        url: _config.supabaseUrl,
        anonKey: _config.supabaseAnonKey,
      );
      debugPrint('[SupabaseService] Supabase initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[SupabaseService] Failed to initialize Supabase: $e');
      debugPrint('[SupabaseService] Stack trace: $stackTrace');
      rethrow;
    }

    final healthy = await _verifyConnection();
    if (!healthy) {
      debugPrint('[SupabaseService] Health check failed, but continuing app startup.');
    } else {
      debugPrint('[SupabaseService] Health check passed');
    }
  }

  Future<bool> _verifyConnection() async {
    try {
      final response = await Supabase.instance.client
          .from(_config.healthCheckTable)
          .select()
          .limit(1);

      debugPrint('Supabase health check returned ${response.length} rows.');
      return true;
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('Supabase health check failed: ${Error.safeToString(error)}');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Supabase health check failed'),
        ),
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'Unexpected Supabase health check error: ${Error.safeToString(error)}',
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Unexpected Supabase health check error'),
        ),
      );
      return false;
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  SupabaseConfig get config => _config;
}
