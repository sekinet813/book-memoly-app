import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../core/providers/tag_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/tag_selector.dart';
import '../action_plans/action_plans_feature.dart';
import '../../shared/constants/app_icons.dart';

const _paperColor = Color(0xFFF7F9F7);

final memosNotifierProvider =
    StateNotifierProvider<MemosNotifier, MemoState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return MemosNotifier(repository)..loadBooks();
});

class MemoState {
  const MemoState({
    required this.books,
    required this.notes,
    required this.noteTags,
    this.selectedBookId,
    this.isLoadingBooks = false,
  });

  final List<BookRow> books;
  final AsyncValue<List<NoteRow>> notes;
  final Map<int, List<TagRow>> noteTags;
  final int? selectedBookId;
  final bool isLoadingBooks;

  MemoState copyWith({
    List<BookRow>? books,
    AsyncValue<List<NoteRow>>? notes,
    Map<int, List<TagRow>>? noteTags,
    int? selectedBookId,
    bool? isLoadingBooks,
  }) {
    return MemoState(
      books: books ?? this.books,
      notes: notes ?? this.notes,
      noteTags: noteTags ?? this.noteTags,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      isLoadingBooks: isLoadingBooks ?? this.isLoadingBooks,
    );
  }
}

class MemosNotifier extends StateNotifier<MemoState> {
  MemosNotifier(this._repository)
      : super(const MemoState(
          books: [],
          notes: AsyncValue.data([]),
          noteTags: {},
          isLoadingBooks: true,
        ));

  final LocalDatabaseRepository _repository;

  Future<void> loadBooks() async {
    state = state.copyWith(isLoadingBooks: true);

    try {
      final books = await _repository.getAllBooks();
      final selectedBookId = books.isNotEmpty ? books.first.id : null;

      state = state.copyWith(
        books: books,
        selectedBookId: selectedBookId,
        isLoadingBooks: false,
        notes: selectedBookId != null
            ? const AsyncValue.loading()
            : const AsyncValue.data([]),
        noteTags: {},
      );

      if (selectedBookId != null) {
        await loadNotesForBook(selectedBookId);
      }
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoadingBooks: false,
        notes: AsyncValue.error(error, stackTrace),
      );
    }
  }

  Future<void> loadNotesForBook(int bookId) async {
    state = state.copyWith(
      selectedBookId: bookId,
      notes: const AsyncValue.loading(),
      noteTags: {},
    );

    try {
      final notes = await _repository.getNotesForBook(bookId);
      final sortedNotes = [...notes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final noteTags = await _repository
          .getTagsForNotes(sortedNotes.map((note) => note.id).toList());

      state = state.copyWith(
        notes: AsyncValue.data(sortedNotes),
        noteTags: noteTags,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(notes: AsyncValue.error(error, stackTrace));
    }
  }

  Future<void> addNote({
    required int bookId,
    required String content,
    int? pageNumber,
    List<int> tagIds = const [],
  }) async {
    final noteId = await _repository.addNote(
      bookId: bookId,
      content: content,
      pageNumber: pageNumber,
    );
    await _repository.setTagsForNote(noteId: noteId, tagIds: tagIds);
    await loadNotesForBook(bookId);
  }

  Future<void> updateNote({
    required int noteId,
    required int bookId,
    required String content,
    int? pageNumber,
    List<int> tagIds = const [],
  }) async {
    await _repository.updateNote(
      noteId: noteId,
      content: content,
      pageNumber: pageNumber,
    );
    await _repository.setTagsForNote(noteId: noteId, tagIds: tagIds);
    await loadNotesForBook(bookId);
  }

  Future<void> deleteNote({
    required int noteId,
    required int bookId,
  }) async {
    await _repository.deleteNote(noteId);
    await loadNotesForBook(bookId);
  }
}

class MemosPage extends ConsumerWidget {
  const MemosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memosNotifierProvider);

    return AppPage(
      title: '読書メモ',
      padding: const EdgeInsets.all(AppSpacing.large),
      currentDestination: AppDestination.memos,
      backgroundColor: _paperColor,
      floatingActionButton: state.selectedBookId != null
          ? FloatingActionButton(
              onPressed: () => _showNoteDialog(context, ref),
              child: const Icon(AppIcons.add),
            )
          : null,
      child: Column(
        children: [
          const _TagManagerSection(),
          const SizedBox(height: AppSpacing.medium),
          _BookSelector(state: state),
          const SizedBox(height: AppSpacing.large),
          Expanded(child: _MemoList(state: state)),
        ],
      ),
    );
  }
}

class _TagManagerSection extends ConsumerWidget {
  const _TagManagerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagState = ref.watch(tagsNotifierProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.label),
              const SizedBox(width: AppSpacing.small),
              Text(
                'タグ管理',
                style: AppTextStyles.sectionTitle(context),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'タグを追加',
                icon: const Icon(AppIcons.add),
                onPressed: () async {
                  final name = await _promptForTagName(context);
                  if (name != null) {
                    await ref.read(tagsNotifierProvider.notifier).addTag(name);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          tagState.when(
            loading: () => const LoadingIndicator(),
            error: (error, _) => Text('タグの取得に失敗しました: $error'),
            data: (tags) {
              if (tags.isEmpty) {
                return const Text('まだタグがありません。追加ボタンから作成できます。');
              }

              return Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: tags
                    .map(
                      (tag) => InputChip(
                        label: Text(tag.name),
                        onPressed: () async {
                          final name = await _promptForTagName(
                            context,
                            initialValue: tag.name,
                            title: 'タグを編集',
                          );
                          if (name != null) {
                            await ref
                                .read(tagsNotifierProvider.notifier)
                                .renameTag(tag.id, name);
                          }
                        },
                        onDeleted: () async {
                          final confirmed = await _confirmTagDeletion(
                            context,
                            tagName: tag.name,
                          );
                          if (confirmed) {
                            await ref
                                .read(tagsNotifierProvider.notifier)
                                .deleteTag(tag.id);
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<String?> _promptForTagName(
  BuildContext context, {
  String? initialValue,
  String title = 'タグを追加',
}) async {
  final controller = TextEditingController(text: initialValue);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
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
            label: '保存',
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    return controller.text.trim().isEmpty ? null : controller.text.trim();
  }

  return null;
}

Future<bool> _confirmTagDeletion(BuildContext context,
    {required String tagName}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('タグを削除しますか？'),
        content: Text('タグ「$tagName」を削除します。関連付けも解除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: '削除',
          ),
        ],
      );
    },
  ).then((value) => value ?? false);
}

class _BookSelector extends ConsumerWidget {
  const _BookSelector({required this.state});

  final MemoState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingBooks) {
      return const LoadingIndicator();
    }

    if (state.books.isEmpty) {
      return const EmptyState(
        title: '登録済みの本がありません',
        message: '本を追加してからメモを作成できます。',
        icon: AppIcons.menuBook,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.medium,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeRadius,
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '書籍ノート',
            style: AppTextStyles.title(context).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Row(
            children: [
              const Icon(AppIcons.menuBook),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.selectedBookId,
                    isExpanded: true,
                    borderRadius: AppRadius.largeRadius,
                    items: state.books
                        .map(
                          (book) => DropdownMenuItem(
                            value: book.id,
                            child: Text(
                              book.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (bookId) {
                      if (bookId != null) {
                        ref
                            .read(memosNotifierProvider.notifier)
                            .loadNotesForBook(bookId);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoList extends ConsumerWidget {
  const _MemoList({required this.state});

  final MemoState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.books.isEmpty) {
      return const SizedBox.shrink();
    }

    return state.notes.when(
      data: (notes) {
        if (notes.isEmpty) {
          return const EmptyState(
            title: 'この本のメモはまだありません',
            message: '気づきや引用をメモしてみましょう。',
            icon: AppIcons.note,
          );
        }

        return ListView.separated(
          itemCount: notes.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.medium),
          itemBuilder: (context, index) {
            final note = notes[index];
            return _MemoCard(note: note);
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (error, _) => EmptyState(
        title: 'メモの取得に失敗しました',
        message: 'メモの読み込み中にエラーが発生しました\n$error',
        icon: AppIcons.error,
      ),
    );
  }
}

class _MemoCard extends ConsumerWidget {
  const _MemoCard({required this.note});

  final NoteRow note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = MaterialLocalizations.of(context);
    final createdDate = localizations.formatShortDate(note.createdAt.toLocal());
    final createdTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(note.createdAt.toLocal()),
      alwaysUse24HourFormat: true,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.pageNumber != null)
                Chip(
                  label: Text('p.${note.pageNumber}'),
                  avatar: const Icon(AppIcons.bookmarkBorder,
                      size: AppIconSizes.small),
                ),
              const Spacer(),
              _MemoActions(note: note),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          _MemoContent(text: note.content),
          const SizedBox(height: AppSpacing.small),
          TagChipList(
            tags:
                ref.watch(memosNotifierProvider).noteTags[note.id] ?? const [],
          ),
          const SizedBox(height: AppSpacing.medium),
          Row(
            children: [
              Icon(
                AppIcons.today,
                size: AppIconSizes.small,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.small),
              Text(
                '作成: $createdDate $createdTime',
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoContent extends StatelessWidget {
  const _MemoContent({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTextStyles.bodyLarge(context).copyWith(height: 1.7);
    final bulletStyle = baseStyle.copyWith(fontWeight: FontWeight.w600);
    final quoteStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
            child: _buildStyledLine(
              context,
              line,
              baseStyle,
              bulletStyle,
              quoteStyle,
            ),
          ),
      ],
    );
  }

  Widget _buildStyledLine(
    BuildContext context,
    String line,
    TextStyle? baseStyle,
    TextStyle? bulletStyle,
    TextStyle? quoteStyle,
  ) {
    if (line.trim().isEmpty) {
      return const SizedBox(height: AppSpacing.small);
    }

    final bulletMatch = RegExp(r'^\s*[-*・]\s+(.*)$').firstMatch(line);
    if (bulletMatch != null) {
      final bulletText = bulletMatch.group(1) ?? '';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xSmall),
            child: Text('•', style: bulletStyle),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              bulletText,
              style: baseStyle,
              softWrap: true,
            ),
          ),
        ],
      );
    }

    final quoteMatch = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
    if (quoteMatch != null) {
      final quoteText = quoteMatch.group(1) ?? '';
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: AppRadius.mediumRadius,
          border: Border(
            left: BorderSide(
              color: colorScheme.outlineVariant,
              width: AppSpacing.xSmall,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        child: Text(
          quoteText,
          style: quoteStyle,
        ),
      );
    }

    return Text(
      line,
      style: baseStyle,
      softWrap: true,
    );
  }
}

class _MemoActions extends ConsumerWidget {
  const _MemoActions({required this.note});

  final NoteRow note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBookId = ref.watch(memosNotifierProvider).selectedBookId;

    return Wrap(
      spacing: AppSpacing.small,
      children: [
        IconButton(
          tooltip: '編集',
          icon: const Icon(AppIcons.edit),
          onPressed: selectedBookId == null
              ? null
              : () => _showNoteDialog(context, ref, note: note),
        ),
        IconButton(
          tooltip: 'アクションを作成',
          icon: const Icon(AppIcons.checklist),
          onPressed: () => _showActionFromNoteDialog(context, ref, note),
        ),
        IconButton(
          tooltip: '削除',
          icon: const Icon(AppIcons.deleteOutline),
          onPressed: selectedBookId == null
              ? null
              : () => _confirmDelete(context, ref, noteId: note.id),
        ),
      ],
    );
  }
}

Future<void> _showNoteDialog(BuildContext context, WidgetRef ref,
    {NoteRow? note}) async {
  final contentController = TextEditingController(text: note?.content ?? '');
  final pageController =
      TextEditingController(text: note?.pageNumber?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  final initialTagIds = note != null
      ? ref
              .read(memosNotifierProvider)
              .noteTags[note.id]
              ?.map((tag) => tag.id)
              .toSet() ??
          <int>{}
      : <int>{};
  var selectedTagIds = {...initialTagIds};

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text(note == null ? 'メモを追加' : 'メモを編集'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: 'メモ',
                    hintText: '読書メモを入力してください',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                      vertical: AppSpacing.medium,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.largeRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.largeRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.largeRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.4,
                      ),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  minLines: 6,
                  style: AppTextStyles.bodyLarge(context).copyWith(height: 1.6),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'メモを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: pageController,
                  decoration: InputDecoration(
                    labelText: 'ページ番号 (任意)',
                    hintText: '例: 25',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                      vertical: AppSpacing.medium,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mediumRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mediumRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mediumRadius,
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.medium),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'タグ',
                    style: AppTextStyles.title(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                TagSelector(
                  selectedTagIds: selectedTagIds,
                  onSelectionChanged: (ids) {
                    setState(() => selectedTagIds = ids);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            PrimaryButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              label: '保存',
            ),
          ],
        );
      });
    },
  );

  if (confirmed != true) {
    return;
  }

  final selectedBookId = ref.read(memosNotifierProvider).selectedBookId;
  if (selectedBookId == null) {
    return;
  }

  final pageNumberText = pageController.text.trim();
  final pageNumber = int.tryParse(pageNumberText.isEmpty ? '' : pageNumberText);

  if (note == null) {
    await ref.read(memosNotifierProvider.notifier).addNote(
          bookId: selectedBookId,
          content: contentController.text.trim(),
          pageNumber: pageNumber,
          tagIds: selectedTagIds.toList(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモを追加しました')),
      );
    }
  } else {
    await ref.read(memosNotifierProvider.notifier).updateNote(
          noteId: note.id,
          bookId: selectedBookId,
          content: contentController.text.trim(),
          pageNumber: pageNumber,
          tagIds: selectedTagIds.toList(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メモを更新しました')),
      );
    }
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
    {required int noteId}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('このメモを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: '削除',
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  final selectedBookId = ref.read(memosNotifierProvider).selectedBookId;
  if (selectedBookId == null) {
    return;
  }

  await ref
      .read(memosNotifierProvider.notifier)
      .deleteNote(noteId: noteId, bookId: selectedBookId);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('メモを削除しました')),
    );
  }
}

Future<void> _showActionFromNoteDialog(
  BuildContext context,
  WidgetRef ref,
  NoteRow note,
) async {
  if (!context.mounted) {
    return;
  }

  await ref
      .read(actionPlansNotifierProvider.notifier)
      .ensureBooksLoaded(initialBookId: note.bookId);

  if (!context.mounted) {
    return;
  }

  await showActionPlanDialog(
    context,
    ref,
    bookId: note.bookId,
    note: note,
  );
}
