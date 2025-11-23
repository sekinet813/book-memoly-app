import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../database/app_database.dart';
import '../providers/tag_providers.dart';
import '../../shared/constants/app_icons.dart';
import 'common_button.dart';
import 'empty_state.dart';
import 'loading_indicator.dart';

class TagSelector extends ConsumerWidget {
  const TagSelector({
    super.key,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.showAddButton = true,
  });

  final Set<int> selectedTagIds;
  final ValueChanged<Set<int>> onSelectionChanged;
  final bool showAddButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagState = ref.watch(tagsNotifierProvider);

    return tagState.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => EmptyState(
        title: 'タグを読み込めませんでした',
        message: error.toString(),
        icon: AppIcons.error,
      ),
      data: (tags) {
        if (tags.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('タグがまだありません'),
              const SizedBox(height: 8),
              if (showAddButton)
                SecondaryButton(
                  onPressed: () => _showTagDialog(context, ref),
                  icon: AppIcons.add,
                  label: 'タグを追加',
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => FilterChip(
                      label: Text(tag.name),
                      selected: selectedTagIds.contains(tag.id),
                      onSelected: (selected) {
                        final updated = {...selectedTagIds};
                        if (selected) {
                          updated.add(tag.id);
                        } else {
                          updated.remove(tag.id);
                        }
                        onSelectionChanged(updated);
                      },
                    ),
                  )
                  .toList(),
            ),
            if (showAddButton) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showTagDialog(context, ref),
                icon: const Icon(AppIcons.add),
                label: const Text('タグを追加'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showTagDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('タグを追加'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'タグ名'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: '追加',
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(tagsNotifierProvider.notifier).addTag(controller.text);
    }
  }
}

class TagChipList extends StatelessWidget {
  const TagChipList({super.key, required this.tags});

  final List<TagRow> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map(
            (tag) => Chip(
              label: Text(tag.name),
              visualDensity: VisualDensity.compact,
            ),
          )
          .toList(),
    );
  }
}
