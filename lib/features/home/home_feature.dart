import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/constants/app_icons.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppPage(
      title: AppConstants.appName,
      actions: [
        IconButton(
          tooltip: '設定',
          onPressed: () {
            context.push('/profile');
          },
          icon: const Icon(AppIcons.settings),
        ),
        IconButton(
          tooltip: 'ログアウト',
          onPressed: () async {
            final authService = ref.read(authServiceProvider);
            if (authService != null) {
              await authService.signOut();
            }
          },
          icon: const Icon(AppIcons.logout),
        ),
      ],
      padding: EdgeInsets.zero,
      scrollable: true,
      currentDestination: AppDestination.home,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'ようこそ',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '読書記録とメモを管理しましょう',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            const _ProfileSummaryCard(),
            const SizedBox(height: 24),
            Text(
              'クイックアクセス',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: [
                _FeatureCard(
                  icon: AppIcons.search,
                  title: '書籍検索',
                  description: 'Google Books APIで\n書籍を検索',
                  color: colorScheme.primary,
                  onTap: () => context.push('/search'),
                ),
                _FeatureCard(
                  icon: AppIcons.books,
                  title: '読書記録',
                  description: '読んだ本を\n管理',
                  color: colorScheme.secondary,
                  onTap: () => context.push('/reading-speed'),
                ),
                _FeatureCard(
                  icon: AppIcons.memo,
                  title: 'メモ',
                  description: '読書メモを\n作成・管理',
                  color: colorScheme.tertiary,
                  onTap: () => context.push('/memos'),
                ),
                _FeatureCard(
                  icon: AppIcons.readingSpeed,
                  title: '読書速度',
                  description: '読書速度を\n測定・記録',
                  color: colorScheme.primary,
                  onTap: () => context.push('/reading-speed'),
                ),
                _FeatureCard(
                  icon: AppIcons.actions,
                  title: 'アクションプラン',
                  description: '読書後の\nアクションを管理',
                  color: colorScheme.secondary,
                  onTap: () => context.push('/actions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: AppIconSizes.large,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(
                AppIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends ConsumerWidget {
  const _ProfileSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final profileService = ref.watch(profileServiceProvider);

    if (profileService == null) {
      return const SizedBox.shrink();
    }

    final profile = profileState.profile;

    return AppCard(
      onTap: () => context.push('/profile'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: profile?.avatarUrl != null
                ? NetworkImage(profile!.avatarUrl!)
                : null,
            child:
                profile?.avatarUrl == null ? const Icon(AppIcons.person) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile?.name.isNotEmpty == true
                            ? profile!.name
                            : 'プロフィールを設定しましょう',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(AppIcons.chevronRight),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.bio?.isNotEmpty == true
                      ? profile!.bio!
                      : '名前や一言、読書テーマを編集できます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile != null && profile.readingThemes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.readingThemes
                        .map(
                          (theme) => Chip(
                            label: Text(theme),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
