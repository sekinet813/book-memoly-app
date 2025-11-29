import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/text_styles.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/common_button.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/constants/app_icons.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authServiceProvider)?.resetFeedback();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendSignUpLink() async {
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

      await authService.sendSignUpLink(_emailController.text);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '新規アカウント作成',
            style: AppTextStyles.pageTitle(context),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'メールアドレスを入力すると、登録用のリングを送信します。',
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
                  onPressed: _isLoading ? null : _sendSignUpLink,
                  label: _isLoading ? '送信中...' : '登録用のリングを送信',
                  expand: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('すでにアカウントをお持ちの方'),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('ログイン'),
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
                      '登録用のリングを送信しました。メールを確認してください。',
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
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
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
