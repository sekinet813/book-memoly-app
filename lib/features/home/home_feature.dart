import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/constants/app_constants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'ようこそ',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '読書記録とメモを管理しましょう',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _FeatureCard(
                      icon: Icons.search,
                      title: '書籍検索',
                      description: 'Google Books APIで\n書籍を検索',
                      color: Colors.blue,
                      onTap: () {
                        context.push('/search');
                      },
                    ),
                    _FeatureCard(
                      icon: Icons.library_books,
                      title: '読書記録',
                      description: '読んだ本を\n管理',
                      color: Colors.green,
                      onTap: () {
                        // TODO: 実装後にナビゲーションを追加
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('準備中です'),
                          ),
                        );
                      },
                    ),
                    _FeatureCard(
                      icon: Icons.note,
                      title: 'メモ',
                      description: '読書メモを\n作成・管理',
                      color: Colors.orange,
                      onTap: () {
                        context.push('/memos');
                      },
                    ),
                    _FeatureCard(
                      icon: Icons.speed,
                      title: '読書速度',
                      description: '読書速度を\n測定・記録',
                      color: Colors.purple,
                      onTap: () {
                        // TODO: 実装後にナビゲーションを追加
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('準備中です'),
                          ),
                        );
                      },
                    ),
                    _FeatureCard(
                      icon: Icons.checklist,
                      title: 'アクションプラン',
                      description: '読書後の\nアクションを管理',
                      color: Colors.teal,
                      onTap: () {
                        context.push('/actions');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

