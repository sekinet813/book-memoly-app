class SupabaseConfig {
  const SupabaseConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabaseFunctionsUrl,
    this.healthCheckTable = 'health_checks',
    this.authRedirectUrl,
  });

  factory SupabaseConfig.fromEnvironment() {
    return const SupabaseConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      supabaseFunctionsUrl: String.fromEnvironment('SUPABASE_FUNCTION_URL'),
      authRedirectUrl: String.fromEnvironment('SUPABASE_REDIRECT_URL'),
    );
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
