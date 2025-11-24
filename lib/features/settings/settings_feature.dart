import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/providers/profile_providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../shared/constants/app_icons.dart';
import '../../core/theme/tokens/spacing.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool notificationsEnabled = true;
  bool weeklyDigestEnabled = false;
  bool darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.profile;

    return AppPage(
      title: 'Settings',
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large, vertical: 12),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeroCard(profileName: profile?.name, bio: profile?.bio),
          const SizedBox(height: AppSpacing.xLarge),
          _SettingsSection(
            title: 'ユーザー設定',
            subtitle: 'プロフィールと読書の習慣づくり',
            icon: AppIcons.person,
            children: [
              _SettingsTile(
                icon: AppIcons.person,
                title: 'プロフィール',
                subtitle: '表示名・自己紹介・読書テーマを編集',
                onTap: () => context.push('/profile'),
              ),
              _SettingsTile(
                icon: AppIcons.goal,
                title: '読書目標',
                subtitle: '月の読了数や読書時間を設定して進捗を確認',
                trailing: FilledButton.icon(
                  onPressed: () => _showSheet(
                    context,
                    icon: AppIcons.goal,
                    title: '読書目標',
                    description: '読書目標の作成と進捗管理機能を準備しています。\nまもなく利用できるようになります。',
                    primaryActionLabel: 'アップデート通知を受け取る',
                  ),
                  icon: const Icon(AppIcons.chevronRight, size: 18),
                  label: const Text('近日公開'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          _SettingsSection(
            title: 'アプリ体験',
            subtitle: '通知・テーマ・データ管理',
            icon: AppIcons.palette,
            children: [
              _SettingsTile(
                icon: AppIcons.notifications,
                title: '通知',
                subtitle: 'リマインドや新機能のお知らせを受け取る',
                trailing: Switch(
                  value: notificationsEnabled,
                  onChanged: (value) => setState(() => notificationsEnabled = value),
                ),
              ),
              _SettingsTile(
                icon: AppIcons.notifications,
                title: 'ウィークリーダイジェスト',
                subtitle: '1週間の読書ハイライトをまとめて通知',
                trailing: Switch(
                  value: weeklyDigestEnabled,
                  onChanged: (value) => setState(() => weeklyDigestEnabled = value),
                ),
              ),
              _SettingsTile(
                icon: AppIcons.darkMode,
                title: 'ダークモード',
                subtitle: '目に優しい配色で集中する',
                trailing: Switch(
                  value: darkModeEnabled,
                  onChanged: (value) {
                    setState(() => darkModeEnabled = value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(value
                            ? 'ダークテーマを適用しました (デバイス設定と連動)'
                            : 'システム設定のテーマを使用します'),
                      ),
                    );
                  },
                ),
              ),
              _SettingsTile(
                icon: AppIcons.export,
                title: 'エクスポート',
                subtitle: 'CSV で読書履歴やメモをバックアップ',
                onTap: () => _showSheet(
                  context,
                  icon: AppIcons.export,
                  title: 'エクスポート',
                  description: '読書データのエクスポートは次回リリースで提供予定です。\n必要な形式や項目の要望があればフィードバックしてください。',
                  primaryActionLabel: '要望を送る',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          _SettingsSection(
            title: 'アカウント',
            subtitle: 'セキュリティとデータ管理',
            icon: AppIcons.shield,
            children: [
              _SettingsTile(
                icon: AppIcons.warning,
                title: 'アカウント削除',
                subtitle: 'データを含めて完全に削除します',
                isDestructive: true,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSheet(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String primaryActionLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.chevronRight),
                  label: Text(primaryActionLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アカウントを削除しますか？'),
          content: const Text('この操作は取り消せません。バックアップを確認してから実行してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(AppIcons.delete),
              label: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アカウント削除リクエストを受け付けました。サポートよりご案内します。'),
        ),
      );
    }
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({this.profileName, this.bio});

  final String? profileName;
  final String? bio;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      backgroundColor: colorScheme.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.1),
                child: const Icon(AppIcons.person, size: 30),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileName?.isNotEmpty == true ? profileName! : '未設定のユーザー',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimaryContainer,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio?.isNotEmpty == true
                          ? bio!
                          : 'プロフィールを設定して、読書体験をパーソナライズしましょう。',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _StatusChip(icon: AppIcons.goal, label: '目標'),
              _StatusChip(icon: AppIcons.notifications, label: '通知'),
              _StatusChip(icon: AppIcons.darkMode, label: 'テーマ'),
              _StatusChip(icon: AppIcons.export, label: 'エクスポート'),
            ],
          )
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimaryContainer.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onPrimaryContainer.withOpacity(0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle, icon: icon),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i != 0)
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = isDestructive ? colorScheme.error : colorScheme.onSurface;
    final baseIconColor = isDestructive ? colorScheme.error : colorScheme.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: baseIconColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: baseIconColor),
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: trailing ?? Icon(AppIcons.chevronRight, color: colorScheme.onSurfaceVariant),
    );
  }
}
