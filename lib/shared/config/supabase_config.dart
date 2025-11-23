class SupabaseConfig {
  const SupabaseConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.healthCheckTable = 'health_checks',
    this.authRedirectUrl,
  });

  factory SupabaseConfig.fromEnvironment() {
    return const SupabaseConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      authRedirectUrl: String.fromEnvironment('SUPABASE_REDIRECT_URL'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String healthCheckTable;
  final String? authRedirectUrl;

  bool get isValid =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
