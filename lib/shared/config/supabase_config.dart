import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  const SupabaseConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabaseFunctionsUrl,
    this.healthCheckTable = 'health_checks',
    this.authRedirectUrl,
  });

  factory SupabaseConfig.fromEnvironment() {
    final supabaseUrlValue = _resolveEnv('SUPABASE_URL');
    final supabaseAnonKeyValue = _resolveEnv('SUPABASE_ANON_KEY');
    final redirectUrlValue = _resolveEnv('SUPABASE_REDIRECT_URL');
    final functionsUrlValue = _resolveEnv('SUPABASE_FUNCTION_URL');

    final supabaseUrl = supabaseUrlValue.value;
    final supabaseAnonKey = supabaseAnonKeyValue.value;
    final redirectUrl = redirectUrlValue.value;
    final functionsUrl = functionsUrlValue.value;

    // Debug: Print what we got from environment
    debugPrint('[SupabaseConfig] Reading environment variables:');
    debugPrint('[SupabaseConfig]   SUPABASE_URL: '
        '${supabaseUrl.isEmpty ? "EMPTY" : "${supabaseUrl.substring(0, supabaseUrl.length > 30 ? 30 : supabaseUrl.length)}..."}'
        ' (${supabaseUrlValue.source})');
    debugPrint('[SupabaseConfig]   SUPABASE_ANON_KEY: '
        '${supabaseAnonKey.isEmpty ? "EMPTY" : "length=${supabaseAnonKey.length}"}'
        ' (${supabaseAnonKeyValue.source})');
    debugPrint('[SupabaseConfig]   SUPABASE_REDIRECT_URL: '
        '${redirectUrl.isEmpty ? "EMPTY" : redirectUrl}'
        ' (${redirectUrlValue.source})');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('[SupabaseConfig] ⚠️ Missing environment variables:');
      if (supabaseUrl.isEmpty) {
        debugPrint('[SupabaseConfig]   - SUPABASE_URL is empty');
      }
      if (supabaseAnonKey.isEmpty) {
        debugPrint('[SupabaseConfig]   - SUPABASE_ANON_KEY is empty');
      }
      debugPrint('[SupabaseConfig] Make sure to:');
      debugPrint('[SupabaseConfig]   1. Create .env file in project root');
      debugPrint('[SupabaseConfig]   2. Add SUPABASE_URL and SUPABASE_ANON_KEY');
      debugPrint('[SupabaseConfig]   3. Add .env to pubspec.yaml assets section');
      debugPrint('[SupabaseConfig]   4. Run app using: ./run.sh');
    }

    return SupabaseConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      supabaseFunctionsUrl: functionsUrl.isEmpty ? null : functionsUrl,
      authRedirectUrl: redirectUrl.isEmpty ? null : redirectUrl,
    );
  }

  static _EnvValue _resolveEnv(String key) {
    final dotenvRaw = dotenv.env[key];
    final dotenvValue = dotenvRaw?.trim() ?? '';
    if (dotenvValue.isNotEmpty) {
      return _EnvValue(dotenvValue, 'flutter_dotenv');
    }

    final dartDefineValue = String.fromEnvironment(key).trim();
    if (dartDefineValue.isNotEmpty) {
      return _EnvValue(dartDefineValue, 'dart-define');
    }

    // If the key exists in dotenv but is empty, mark the source for debugging.
    if (dotenvRaw != null) {
      return _EnvValue('', 'flutter_dotenv (empty)');
    }

    return const _EnvValue('', 'unset');
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? supabaseFunctionsUrl;
  final String healthCheckTable;
  final String? authRedirectUrl;

  bool get isValid =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  String get functionsBaseUrl {
    final explicit = supabaseFunctionsUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return _removeTrailingSlash(explicit);
    }

    return _deriveFunctionsUrlFromSupabaseUrl();
  }

  String _deriveFunctionsUrlFromSupabaseUrl() {
    final trimmed = supabaseUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final normalized = _removeTrailingSlash(trimmed);
    final uri = Uri.tryParse(normalized);

    if (uri == null || uri.host.isEmpty) {
      return normalized.endsWith('/functions/v1')
          ? normalized
          : '$normalized/functions/v1';
    }

    final host = uri.host;
    final isLocalHost = host == 'localhost' ||
        host == '127.0.0.1' ||
        RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host);

    if (isLocalHost) {
      return normalized.endsWith('/functions/v1')
          ? normalized
          : '$normalized/functions/v1';
    }

    if (!host.contains('.supabase.co')) {
      return normalized;
    }

    final functionsHost =
        host.replaceFirst('.supabase.co', '.functions.supabase.co');
    final functionsUri = uri.replace(
      host: functionsHost,
      path: '',
      query: '',
      fragment: '',
    );

    return _removeTrailingSlash(functionsUri.toString());
  }

  String _removeTrailingSlash(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

class _EnvValue {
  const _EnvValue(this.value, this.source);

  final String value;
  final String source;
}
