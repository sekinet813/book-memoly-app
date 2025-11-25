import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/providers/profile_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/app_logo.dart';
import '../../shared/constants/app_icons.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/typography.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final profile = profileState.profile;
    final notificationSettings = ref.watch(notificationSettingsNotifierProvider);

    return AppPage(
      title: 'Settings',
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large, vertical: 12),
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
                subtitle: '年間・月間の目標値を設定して進捗を確認',
                onTap: () => context.push('/goals'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          _SettingsSection(
            title: 'アプリ体験',
            subtitle: '通知・テーマ・データ管理',
            icon: AppIcons.palette,
            children: [
              const _FontScaleTile(),
              const _ThemeModeTile(),
              _NotificationSettingsTile(settings: notificationSettings),
              _SettingsTile(
                icon: AppIcons.export,
                title: 'エクスポート',
                subtitle: 'CSV で読書履歴やメモをバックアップ',
                onTap: () => _showSheet(
                  context,
                  icon: AppIcons.export,
                  title: 'エクスポート',
                  description:
                      '読書データのエクスポートは次回リリースで提供予定です。\n必要な形式や項目の要望があればフィードバックしてください。',
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
          const _BrandFooter(),
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
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(icon,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
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

    if (!mounted) {
      return;
    }

    if (result == true) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アカウント削除リクエストを受け付けました。サポートよりご案内します。'),
        ),
      );
    }
  }
}

class _NotificationSettingsTile extends ConsumerWidget {
  const _NotificationSettingsTile({required this.settings});

  final AsyncValue<NotificationSettingsState> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return settings.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => _SettingsTile(
        icon: AppIcons.notifications,
        title: '通知設定',
        subtitle: '読み込みに失敗しました: $error',
        trailing: const Icon(AppIcons.refresh),
        onTap: () =>
            ref.invalidate(notificationSettingsNotifierProvider),
      ),
      data: (state) {
        final notifier =
            ref.read(notificationSettingsNotifierProvider.notifier);
        final subtitle = state.permissionGranted
            ? '毎日の読書リマインドと読後メモの促しを受け取る'
            : '通知許可が必要です。端末の設定を確認してください。';

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      AppIcons.notifications,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '読書習慣サポート',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.reminderEnabled,
                    onChanged: notifier.updateReminderEnabled,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '読書リマインド',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '通知時間: ${state.reminderTime.format(context)}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '頻度: ${state.reminderFrequency.label}' +
                              (state.reminderFrequency ==
                                      ReminderFrequency.weekly
                                  ? '（${_weekdayLabel(state.weeklyWeekday)}）'
                                  : ''),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickTime(context, notifier, state),
                    icon: const Icon(AppIcons.schedule),
                    label: const Text('時間を変更'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
              SegmentedButton<ReminderFrequency>(
                segments: ReminderFrequency.values
                    .map(
                      (frequency) => ButtonSegment(
                        value: frequency,
                        label: Text(frequency.label),
                      ),
                    )
                    .toList(),
                selected: {state.reminderFrequency},
                onSelectionChanged: (selection) => notifier
                    .updateReminderFrequency(selection.first),
              ),
              if (state.reminderFrequency == ReminderFrequency.weekly) ...[
                const SizedBox(height: AppSpacing.small),
                DropdownButtonFormField<int>(
                  value: state.weeklyWeekday,
                  decoration: const InputDecoration(
                    labelText: '通知する曜日',
                    border: OutlineInputBorder(),
                  ),
                  items: _weekdayItems()
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.$1,
                          child: Text(entry.$2),
                        ),
                      )
                      .toList(),
                  onChanged: notifier.updateWeeklyWeekday,
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '続き読むリマインダー',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'いま読んでいる本を指定時間にお知らせします。',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.continueReminderEnabled,
                    onChanged: notifier.updateContinueReminderEnabled,
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'アクションプランの期限',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'リマインダー日時を設定したプランを通知します。',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.actionPlanRemindersEnabled,
                    onChanged: notifier.updateActionPlanReminderEnabled,
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '読了後の振り返り',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ログを記録した後に「今日の学びを書く？」を提案します。',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.reflectionPromptEnabled,
                    onChanged: notifier.updateReflectionPromptEnabled,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = {
      DateTime.monday: '月曜日',
      DateTime.tuesday: '火曜日',
      DateTime.wednesday: '水曜日',
      DateTime.thursday: '木曜日',
      DateTime.friday: '金曜日',
      DateTime.saturday: '土曜日',
      DateTime.sunday: '日曜日',
    };

    return labels[weekday] ?? '未設定';
  }

  List<(int, String)> _weekdayItems() {
    return const [
      (DateTime.monday, '月曜日'),
      (DateTime.tuesday, '火曜日'),
      (DateTime.wednesday, '水曜日'),
      (DateTime.thursday, '木曜日'),
      (DateTime.friday, '金曜日'),
      (DateTime.saturday, '土曜日'),
      (DateTime.sunday, '日曜日'),
    ];
  }

  Future<void> _pickTime(
    BuildContext context,
    NotificationSettingsNotifier notifier,
    NotificationSettingsState state,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: state.reminderTime,
    );

    if (picked != null) {
      await notifier.updateReminderTime(picked);
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
                backgroundColor:
                    colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                child: const Icon(AppIcons.person, size: 30),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileName?.isNotEmpty == true
                          ? profileName!
                          : '未設定のユーザー',
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
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
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
        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.14),
        ),
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

class _FontScaleTile extends ConsumerWidget {
  const _FontScaleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fontScale = ref.watch(fontScaleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(AppIcons.text, color: colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文字サイズ',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Small / Normal / Large から選択できます',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final option in AppFontScale.values)
                ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      option.label,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fontScale == option
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  selected: fontScale == option,
                  onSelected: (_) =>
                      ref.read(fontScaleProvider.notifier).update(option),
                  selectedColor: colorScheme.primary,
                  backgroundColor:
                      colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: fontScale == option
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fontScale.description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(AppIcons.darkMode, color: colorScheme.secondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'テーマモード',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ライト / ダーク / システムから選択できます',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.selected)
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
            segments: [
              for (final option in AppThemeMode.values)
                ButtonSegment(value: option, label: Text(option.label)),
            ],
            selected: {themeMode},
            onSelectionChanged: (value) =>
                ref.read(themeModeProvider.notifier).update(value.first),
          ),
          const SizedBox(height: 10),
          Text(
            _themeModeDescription(themeMode),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'デバイスの設定に合わせてテーマを自動切り替えます。';
      case AppThemeMode.light:
        return 'やわらかなライトテーマで明るく閲覧できます。';
      case AppThemeMode.dark:
        return '目に優しい深緑のダークテーマで集中できます。';
    }
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
    final titleColor =
        isDestructive ? colorScheme.error : colorScheme.onSurface;
    final baseIconColor =
        isDestructive ? colorScheme.error : colorScheme.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: baseIconColor.withValues(alpha: 0.08),
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
      trailing: trailing ??
          Icon(AppIcons.chevronRight, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.large),
      child: Column(
        children: [
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.medium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(
                size: 72,
                showWordmark: false,
              ),
              const SizedBox(width: AppSpacing.medium),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book Memoly',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    '読書の記憶を、美しく。',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
