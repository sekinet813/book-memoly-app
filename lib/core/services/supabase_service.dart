import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/config/supabase_config.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  throw UnimplementedError(
    'supabaseServiceProvider must be overridden. '
    'If Supabase is not configured, override with a dummy implementation.',
  );
});

class SupabaseService {
  SupabaseService({SupabaseConfig? config})
      : _config = config ?? SupabaseConfig.fromEnvironment();

  final SupabaseConfig _config;

  Future<void> initialize() async {
    if (!_config.isValid) {
      throw StateError(
        'Supabase configuration missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.',
      );
    }

    await Supabase.initialize(
      url: _config.supabaseUrl,
      anonKey: _config.supabaseAnonKey,
    );

    await _verifyConnection();
  }

  Future<void> _verifyConnection() async {
    try {
      final response = await Supabase.instance.client
          .from(_config.healthCheckTable)
          .select()
          .limit(1);

      debugPrint('Supabase health check returned ${response.length} rows.');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('Supabase health check failed: ${Error.safeToString(error)}');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Supabase health check failed'),
        ),
      );
      rethrow;
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
      rethrow;
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  SupabaseConfig get config => _config;
}
