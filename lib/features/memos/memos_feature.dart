import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../action_plans/action_plans_feature.dart';
import '../../shared/constants/app_icons.dart';

final memosNotifierProvider =
    StateNotifierProvider<MemosNotifier, MemoState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return MemosNotifier(repository)..loadBooks();
});

class MemoState {
  const MemoState({
    required this.books,
    required this.notes,
    this.selectedBookId,
    this.isLoadingBooks = false,
  });

  final List<BookRow> books;
  final AsyncValue<List<NoteRow>> notes;
  final int? selectedBookId;
  final bool isLoadingBooks;

  MemoState copyWith({
    List<BookRow>? books,
    AsyncValue<List<NoteRow>>? notes,
    int? selectedBookId,
    bool? isLoadingBooks,
  }) {
    return MemoState(
      books: books ?? this.books,
      notes: notes ?? this.notes,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      isLoadingBooks: isLoadingBooks ?? this.isLoadingBooks,
    );
  }
}

class MemosNotifier extends StateNotifier<MemoState> {
  MemosNotifier(this._repository)
      : super(const MemoState(
          books: [], notes: AsyncValue.data([]), isLoadingBooks: true));

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
    );

    try {
      final notes = await _repository.getNotesForBook(bookId);
      final sortedNotes = [...notes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(notes: AsyncValue.data(sortedNotes));
    } catch (error, stackTrace) {
      state = state.copyWith(notes: AsyncValue.error(error, stackTrace));
    }
  }

  Future<void> addNote({
    required int bookId,
    required String content,
    int? pageNumber,
  }) async {
    await _repository.addNote(
      bookId: bookId,
      content: content,
      pageNumber: pageNumber,
    );
    await loadNotesForBook(bookId);
  }

  Future<void> updateNote({
    required int noteId,
    required int bookId,
    required String content,
    int? pageNumber,
  }) async {
    await _repository.updateNote(
      noteId: noteId,
      content: content,
      pageNumber: pageNumber,
    );
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _BookSelector(state: state),
          const SizedBox(height: 16),
          Expanded(child: _MemoList(state: state)),
        ],
      ),
      floatingActionButton: state.selectedBookId != null
          ? FloatingActionButton(
              onPressed: () => _showNoteDialog(context, ref),
              child: const Icon(AppIcons.add),
            )
          : null,
    );
  }
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

    return Row(
      children: [
        const Icon(AppIcons.menuBook),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<int>(
            value: state.selectedBookId,
            isExpanded: true,
            items: state.books
                .map(
                  (book) => DropdownMenuItem(
                    value: book.id,
                    child: Text(book.title),
                  ),
                )
                .toList(),
            onChanged: (bookId) {
              if (bookId != null) {
                ref.read(memosNotifierProvider.notifier).loadNotesForBook(bookId);
              }
            },
          ),
        ),
      ],
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
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final createdDate =
        localizations.formatShortDate(note.createdAt.toLocal());
    final createdTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(note.createdAt.toLocal()),
      alwaysUse24HourFormat: true,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.pageNumber != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text('p.${note.pageNumber}'),
                  avatar:
                      const Icon(AppIcons.bookmarkBorder, size: AppIconSizes.small),
                ),
                _MemoActions(note: note),
              ],
            ),
            const SizedBox(height: 8),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: _MemoActions(note: note),
            ),
          Text(
            note.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '作成: $createdDate $createdTime',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
      spacing: 8,
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

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(note == null ? 'メモを追加' : 'メモを編集'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  hintText: '読書メモを入力してください',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'メモを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pageController,
                decoration: const InputDecoration(
                  labelText: 'ページ番号 (任意)',
                  hintText: '例: 25',
                ),
                keyboardType: TextInputType.number,
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
  await ref
      .read(actionPlansNotifierProvider.notifier)
      .ensureBooksLoaded(initialBookId: note.bookId);

  await showActionPlanDialog(
    context,
    ref,
    bookId: note.bookId,
    note: note,
  );
}
