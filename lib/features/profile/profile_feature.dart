import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/profile.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../shared/constants/app_icons.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _themeController = TextEditingController();
  List<String> _readingThemes = [];
  ProviderSubscription<UserProfile?>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _profileSubscription = ref.listenManual(
      profileNotifierProvider.select((value) => value.profile),
      (previous, next) {
        if (previous != next) {
          _applyProfile(next);
        }
      },
    );
    final profile = ref.read(profileNotifierProvider).profile;
    _applyProfile(profile);
  }

  @override
  void dispose() {
    _profileSubscription?.close();
    _nameController.dispose();
    _bioController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  void _applyProfile(UserProfile? profile) {
    if (profile == null) {
      return;
    }
    _nameController.text = profile.name;
    _bioController.text = profile.bio ?? '';
    setState(() {
      _readingThemes = [...profile.readingThemes];
    });
  }

  void _addTheme(String value) {
    final theme = value.trim();
    if (theme.isEmpty) {
      return;
    }
    setState(() {
      if (!_readingThemes.contains(theme)) {
        _readingThemes = [..._readingThemes, theme];
      }
    });
    _themeController.clear();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.saveProfile(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      readingThemes: _readingThemes,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを保存しました')),
      );
      context.pop();
    } else {
      final message = ref.read(profileNotifierProvider).errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) {
      return;
    }

    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.uploadAvatar(file);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アバターを更新しました')),
      );
    } else {
      final message = ref.read(profileNotifierProvider).errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileNotifierProvider.select((value) => value.profile),
        (previous, next) {
      if (previous != next) {
        _applyProfile(next);
      }
    });

    final state = ref.watch(profileNotifierProvider);
    final canUseProfile =
        ref.watch(profileServiceProvider) != null && state.isLoading == false;

    return AppPage(
      title: 'プロフィール設定',
      padding: const EdgeInsets.all(16),
      currentDestination: AppDestination.profile,
      actions: [
        IconButton(
          onPressed: state.isLoading
              ? null
              : () {
                  ref.read(profileNotifierProvider.notifier).reload();
                },
          icon: const Icon(AppIcons.refresh),
          tooltip: '再読み込み',
        ),
      ],
      child: state.isLoading
          ? const Center(child: LoadingIndicator())
          : !canUseProfile
              ? const _ProfileUnavailable()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(
                      profile: state.profile,
                      isSaving: state.isSaving,
                      onChangeAvatar: _pickAvatar,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: '名前',
                                  hintText: '表示したい名前を入力',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '名前は必須です';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _bioController,
                                decoration: const InputDecoration(
                                  labelText: '一言メッセージ',
                                  hintText: '自己紹介や読書の一言',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '読書テーマ',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ..._readingThemes.map(
                                    (theme) => InputChip(
                                      label: Text(theme),
                                      onDeleted: () {
                                        setState(() {
                                          _readingThemes = _readingThemes
                                              .where((item) => item != theme)
                                              .toList();
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: TextField(
                                      controller: _themeController,
                                      decoration: const InputDecoration(
                                        labelText: 'テーマを追加',
                                        hintText: 'Enterで追加',
                                      ),
                                      onSubmitted: _addTheme,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _saveProfile(),
                                  icon: AppIcons.save,
                                  label:
                                      state.isSaving ? '保存中...' : 'プロフィールを保存',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isSaving,
    required this.onChangeAvatar,
  });

  final UserProfile? profile;
  final bool isSaving;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    return AppCard(
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(AppIcons.person, size: 36)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: IconButton.filled(
                  onPressed: isSaving ? null : onChangeAvatar,
                  icon: const Icon(AppIcons.edit, size: 18),
                  tooltip: 'アバターを変更',
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name.isNotEmpty == true ? profile!.name : '未設定のユーザー',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.bio?.isNotEmpty == true
                      ? profile!.bio!
                      : 'プロフィールを設定して読書体験をパーソナライズしましょう',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.error, size: 40),
          const SizedBox(height: 12),
          Text(
            'Supabaseの設定が必要です',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'プロフィール機能を利用するにはSupabaseの接続を有効にしてください。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
