import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/text_styles.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/constants/app_icons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  static const _emailStorageKey = 'login_email';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authServiceProvider)?.resetFeedback();
    });
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_emailStorageKey);
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    }
  }

  Future<void> _storeEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailStorageKey, email);
  }

  Future<void> _sendMagicLink() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_isLoading) {
      return; // 既に処理中の場合は何もしない
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      if (authService == null) {
        // Show error message if Supabase is not configured
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('認証サービスが利用できません。Supabaseの設定を確認してください。'),
            ),
          );
        }
        return;
      }

      final email = _emailController.text;
      await _storeEmail(email);
      await authService.sendMagicLink(email);

      // 成功メッセージを表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メールを送信しました。メールボックスを確認してください。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final magicLinkSent = ref.watch(magicLinkSentProvider);
    final authError = ref.watch(authErrorMessageProvider);

    return AppPage(
      title: AppConstants.appName,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: AppLogo(
              subtitle: '読みたい本とアイデアを鮮やかに残す',
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            'メールアドレスでログイン',
            style: AppTextStyles.pageTitle(context),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'メールアドレスを入力すると、ログイン用のリングを送信します。',
            style: AppTextStyles.bodyLarge(context).copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'メールアドレスを入力してください。';
                    }
                    if (!value.contains('@')) {
                      return 'メールアドレスの形式が正しくありません。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.large),
                PrimaryButton(
                  onPressed: _isLoading ? null : _sendMagicLink,
                  label: _isLoading ? '送信中...' : 'リングを送信',
                  expand: true,
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _sendMagicLink,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.refresh),
                  label: Text(_isLoading ? '送信中...' : '再送'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('はじめての方はこちら'),
              TextButton(
                onPressed: () {
                  context.go('/signup');
                },
                child: const Text('新規登録'),
              ),
            ],
          ),
          if (magicLinkSent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: AppRadius.mediumRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.email,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Text(
                      'リングを送信しました。メールボックスを確認してください。',
                      style: AppTextStyles.bodyLarge(context),
                    ),
                  ),
                ],
              ),
            ),
          if (authError != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: AppRadius.mediumRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.error,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Text(
                      authError,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
