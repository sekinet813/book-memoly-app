import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/config/supabase_config.dart';

enum AuthStatus {
  loading,
  authenticated,
  guest,
  unauthenticated,
}

class AppAuthState {
  const AppAuthState({
    required this.status,
    required this.session,
    this.magicLinkSent = false,
    this.errorMessage,
  });

  factory AppAuthState.initial() => const AppAuthState(
        status: AuthStatus.loading,
        session: null,
      );

  final AuthStatus status;
  final Session? session;
  final bool magicLinkSent;
  final String? errorMessage;

  AppAuthState copyWith({
    AuthStatus? status,
    Session? session,
    bool? magicLinkSent,
    String? errorMessage,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      magicLinkSent: magicLinkSent ?? this.magicLinkSent,
      errorMessage: errorMessage,
    );
  }
}

class AuthService extends ChangeNotifier {
  AuthService({
    required SupabaseClient client,
    SupabaseConfig? config,
  })  : _client = client,
        _config = config ?? SupabaseConfig.fromEnvironment();

  final SupabaseClient _client;
  final SupabaseConfig _config;
  String? get _redirectUrl {
    final redirect = _config.authRedirectUrl?.trim();
    if (redirect == null || redirect.isEmpty) {
      // デフォルトのカスタムURLスキームを使用
      const defaultRedirect = 'com.bookmemoly.app://';
      debugPrint('[AuthService] No redirect URL configured, using default: $defaultRedirect');
      return defaultRedirect;
    }
    debugPrint('[AuthService] Using configured redirect URL: $redirect');
    return redirect;
  }

  AppAuthState _state = AppAuthState.initial();
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;

  AppAuthState get state => _state;

  String? get userId => _state.session?.user.id;

  void resetFeedback() {
    _state = _state.copyWith(magicLinkSent: false, errorMessage: null);
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _authSubscription =
        _client.auth.onAuthStateChange.listen(_handleAuthStateChange);
    await _loadInitialSession();
    await _recoverSessionFromUrl();
  }

  Future<void> _loadInitialSession() async {
    final session = _client.auth.currentSession;
    _state = _state.copyWith(
      session: session,
      status: session != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
    notifyListeners();
  }

  Future<void> _recoverSessionFromUrl([Uri? uri]) async {
    final link = uri ?? Uri.base;
    final params = _extractAuthParams(link);
    final hasAccessToken = params['access_token']?.isNotEmpty ?? false;
    final hasRefreshToken = params['refresh_token']?.isNotEmpty ?? false;

    if (!hasAccessToken || !hasRefreshToken) {
      return;
    }

    try {
      await _client.auth.getSessionFromUrl(link);
    } catch (error) {
      debugPrint('Failed to recover session from deep link: $error');
    }
  }

  Map<String, String> _extractAuthParams(Uri link) {
    final queryParams = <String, String>{...link.queryParameters};
    if (link.fragment.isNotEmpty) {
      try {
        queryParams.addAll(Uri.splitQueryString(link.fragment));
      } on FormatException catch (error) {
        debugPrint('Failed to parse auth fragment: $error');
      }
    }
    return queryParams;
  }

  void _handleAuthStateChange(AuthState authState) {
    final session = authState.session;
    _state = _state.copyWith(
      session: session,
      status: session != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
    notifyListeners();
  }

  Future<void> sendMagicLink(String email) async {
    _state = _state.copyWith(magicLinkSent: false, errorMessage: null);
    notifyListeners();

    final redirectUrl = _redirectUrl;
    debugPrint('[AuthService] Sending magic link to $email with redirect: $redirectUrl');

    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectUrl,
        shouldCreateUser: false,
      );
      _state = _state.copyWith(magicLinkSent: true);
    } on AuthException catch (error, stackTrace) {
      debugPrint('Magic link sign-in failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Magic link sign-in failed'),
        ),
      );
      _state = _state.copyWith(
        errorMessage: 'アカウントが見つかりません。新規登録を行ってください。',
        magicLinkSent: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Magic link sign-in failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Magic link sign-in failed'),
        ),
      );
      _state = _state.copyWith(
        errorMessage: 'ログインリンクの送信に失敗しました。時間を置いて再試行してください。',
        magicLinkSent: false,
      );
    }

    notifyListeners();
  }

  Future<void> sendSignUpLink(String email) async {
    _state = _state.copyWith(magicLinkSent: false, errorMessage: null);
    notifyListeners();

    final redirectUrl = _redirectUrl;
    debugPrint('[AuthService] Sending sign-up link to $email with redirect: $redirectUrl');

    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectUrl,
        shouldCreateUser: true,
      );
      _state = _state.copyWith(magicLinkSent: true);
    } on AuthException catch (error, stackTrace) {
      debugPrint('Magic link sign-up failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Magic link sign-up failed'),
        ),
      );
      final message = error.message.contains('already registered')
          ? 'このメールアドレスは既に登録されています。ログインしてください。'
          : '登録リンクの送信に失敗しました。時間を置いて再試行してください。';
      _state = _state.copyWith(
        errorMessage: message,
        magicLinkSent: false,
      );
    } catch (error, stackTrace) {
      debugPrint('Magic link sign-up failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Magic link sign-up failed'),
        ),
      );
      _state = _state.copyWith(
        errorMessage: '登録リンクの送信に失敗しました。時間を置いて再試行してください。',
        magicLinkSent: false,
      );
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    debugPrint('[AuthService] signOut() called');
    await _client.auth.signOut();
    debugPrint('[AuthService] signOut() completed, updating state');
    // 明示的に状態を更新
    _state = _state.copyWith(
      session: null,
      status: AuthStatus.unauthenticated,
    );
    debugPrint('[AuthService] State updated: status=${_state.status}, session=${_state.session}');
    notifyListeners();
    debugPrint('[AuthService] notifyListeners() called');
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
