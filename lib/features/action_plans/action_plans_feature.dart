import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';

final actionPlansNotifierProvider =
    StateNotifierProvider<ActionPlansNotifier, ActionPlansState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return ActionPlansNotifier(repository)..loadBooks();
});

class ActionPlansState {
  const ActionPlansState({
    required this.books,
    required this.actions,
    required this.notes,
    this.selectedBookId,
    this.isLoadingBooks = false,
  });

  final List<BookRow> books;
  final AsyncValue<List<ActionRow>> actions;
  final List<NoteRow> notes;
  final int? selectedBookId;
  final bool isLoadingBooks;

  ActionPlansState copyWith({
    List<BookRow>? books,
    AsyncValue<List<ActionRow>>? actions,
    List<NoteRow>? notes,
    int? selectedBookId,
    bool? isLoadingBooks,
  }) {
    return ActionPlansState(
      books: books ?? this.books,
      actions: actions ?? this.actions,
      notes: notes ?? this.notes,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      isLoadingBooks: isLoadingBooks ?? this.isLoadingBooks,
    );
  }
}

class ActionPlansNotifier extends StateNotifier<ActionPlansState> {
  ActionPlansNotifier(this._repository)
      : super(const ActionPlansState(
          books: [],
          actions: AsyncValue.data([]),
          notes: [],
          isLoadingBooks: true,
        ));

  final LocalDatabaseRepository _repository;

  Future<void> loadBooks({int? initialBookId}) async {
    state = state.copyWith(isLoadingBooks: true);

    try {
      final books = await _repository.getAllBooks();
      final selectedBookId = initialBookId ?? (books.isNotEmpty ? books.first.id : null);

      state = state.copyWith(
        books: books,
        selectedBookId: selectedBookId,
        isLoadingBooks: false,
        actions: selectedBookId != null
            ? const AsyncValue.loading()
            : const AsyncValue.data([]),
      );

      if (selectedBookId != null) {
        await loadActionsForBook(selectedBookId);
      }
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoadingBooks: false,
        actions: AsyncValue.error(error, stackTrace),
      );
    }
  }

  Future<void> ensureBooksLoaded({int? initialBookId}) async {
    if (state.books.isEmpty) {
      await loadBooks(initialBookId: initialBookId);
      return;
    }

    if (initialBookId != null && state.selectedBookId != initialBookId) {
      await loadActionsForBook(initialBookId);
    }
  }

  Future<void> loadActionsForBook(int bookId) async {
    state = state.copyWith(
      selectedBookId: bookId,
      actions: const AsyncValue.loading(),
    );

    try {
      final actions = await _repository.getActionsForBook(bookId);
      actions.sort((a, b) {
        if (a.status != b.status) {
          return a.status == 'pending' ? -1 : 1;
        }
        return (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt);
      });
      final notes = await _repository.getNotesForBook(bookId);
      state = state.copyWith(
        actions: AsyncValue.data(actions),
        notes: notes,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(actions: AsyncValue.error(error, stackTrace));
    }
  }

  Future<List<NoteRow>> loadNotesForBook(int bookId) async {
    final notes = await _repository.getNotesForBook(bookId);
    if (state.selectedBookId == bookId) {
      state = state.copyWith(notes: notes);
    }
    return notes;
  }

  Future<void> addAction({
    required int bookId,
    required String title,
    String? description,
    DateTime? dueDate,
    int? noteId,
  }) async {
    await _repository.addAction(
      bookId: bookId,
      title: title,
      description: description,
      dueDate: dueDate,
      noteId: noteId,
    );
    await loadActionsForBook(bookId);
  }

  Future<void> updateAction({
    required int actionId,
    required int bookId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? status,
    int? noteId,
  }) async {
    await _repository.updateAction(
      actionId: actionId,
      title: title,
      description: description,
      dueDate: dueDate,
      status: status,
      noteId: noteId,
    );
    await loadActionsForBook(bookId);
  }

  Future<void> deleteAction({
    required int actionId,
    required int bookId,
  }) async {
    await _repository.deleteAction(actionId);
    await loadActionsForBook(bookId);
  }

  Future<void> toggleStatus(ActionRow action, bool isDone) async {
    if (action.bookId == null) {
      return;
    }

    final newStatus = isDone ? 'done' : 'pending';
    await _repository.updateActionStatus(
      actionId: action.id,
      status: newStatus,
    );
    await loadActionsForBook(action.bookId!);
  }
}

class ActionPlansPage extends ConsumerWidget {
  const ActionPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(actionPlansNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('アクションプラン'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _BookSelector(state: state),
              const SizedBox(height: 16),
              Expanded(child: _ActionList(state: state)),
            ],
          ),
        ),
      ),
      floatingActionButton: state.selectedBookId != null
          ? FloatingActionButton(
              onPressed: () => showActionPlanDialog(
                context,
                ref,
                bookId: state.selectedBookId!,
              ),
              child: const Icon(Icons.add_task),
            )
          : null,
    );
  }
}

class _BookSelector extends ConsumerWidget {
  const _BookSelector({required this.state});

  final ActionPlansState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingBooks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.books.isEmpty) {
      return const _InfoCard(
        icon: Icons.menu_book,
        message: 'まずは本を登録してアクションを追加しましょう',
      );
    }

    return Row(
      children: [
        const Icon(Icons.menu_book_outlined),
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
                ref
                    .read(actionPlansNotifierProvider.notifier)
                    .loadActionsForBook(bookId);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ActionList extends ConsumerWidget {
  const _ActionList({required this.state});

  final ActionPlansState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.books.isEmpty) {
      return const SizedBox.shrink();
    }

    return state.actions.when(
      data: (actions) {
        if (actions.isEmpty) {
          return const _InfoCard(
            icon: Icons.checklist_rtl,
            message: 'この本のアクションはまだありません',
          );
        }

        return ListView.separated(
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _ActionTile(action: action, notes: state.notes);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _InfoCard(
        icon: Icons.error_outline,
        message: 'アクションの読み込み中にエラーが発生しました\n$error',
      ),
    );
  }
}

class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.action, required this.notes});

  final ActionRow action;
  final List<NoteRow> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = action.noteId != null
        ? notes.firstWhere(
            (n) => n.id == action.noteId,
            orElse: () => NoteRow(
              id: -1,
              bookId: action.bookId ?? -1,
              content: '',
            ),
          )
        : null;
    final isLinkedToNote = note != null && note.id != -1 && note.content.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: action.status == 'done',
                  onChanged: (value) => ref
                      .read(actionPlansNotifierProvider.notifier)
                      .toggleStatus(action, value ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (action.description?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            action.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      if (action.dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.event, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _formatDueDate(context, action.dueDate!),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      if (isLinkedToNote)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  note!.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _ActionMenu(action: action),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionMenu extends ConsumerWidget {
  const _ActionMenu({required this.action});

  final ActionRow action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: '編集',
          icon: const Icon(Icons.edit_outlined),
          onPressed: action.bookId == null
              ? null
              : () => showActionPlanDialog(
                    context,
                    ref,
                    action: action,
                    bookId: action.bookId!,
                  ),
        ),
        IconButton(
          tooltip: '削除',
          icon: const Icon(Icons.delete_outline),
          onPressed: action.bookId == null
              ? null
              : () => _confirmDelete(context, ref, action),
        ),
      ],
    );
  }
}

Future<void> showActionPlanDialog(
  BuildContext context,
  WidgetRef ref, {
  required int bookId,
  ActionRow? action,
  NoteRow? note,
}) async {
  final notifier = ref.read(actionPlansNotifierProvider.notifier);
  await notifier.ensureBooksLoaded(initialBookId: bookId);
  final notes = await notifier.loadNotesForBook(bookId);

  final titleController = TextEditingController(
    text: action?.title ?? note?.content ?? '',
  );
  final descriptionController = TextEditingController(
    text: action?.description ?? '',
  );
  DateTime? dueDate = action?.dueDate;
  int? selectedNoteId = action?.noteId ?? note?.id;
  final formKey = GlobalKey<FormState>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dueDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                dueDate = picked;
              });
            }
          }

          return AlertDialog(
            title: Text(action == null ? 'アクションを追加' : 'アクションを編集'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'タイトル',
                        hintText: '次に取る行動を入力',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'タイトルを入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: '詳細 (任意)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dueDate == null
                                ? '期日: 未設定'
                                : '期日: ${_formatDueDate(context, dueDate!)}',
                          ),
                        ),
                        if (dueDate != null)
                          IconButton(
                            tooltip: '期日をクリア',
                            onPressed: () {
                              setState(() {
                                dueDate = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                        TextButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.event),
                          label: const Text('期日を選択'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: selectedNoteId,
                      decoration: const InputDecoration(
                        labelText: '関連メモ (任意)',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('なし'),
                        ),
                        ...notes.map(
                          (note) => DropdownMenuItem(
                            value: note.id,
                            child: Text(
                              note.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedNoteId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  if (action == null) {
    await notifier.addAction(
      bookId: bookId,
      title: titleController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      dueDate: dueDate,
      noteId: selectedNoteId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アクションを追加しました')),
      );
    }
  } else {
    await notifier.updateAction(
      actionId: action.id,
      bookId: bookId,
      title: titleController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      dueDate: dueDate,
      status: action.status,
      noteId: selectedNoteId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アクションを更新しました')),
      );
    }
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  ActionRow action,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('このアクションを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || action.bookId == null) {
    return;
  }

  await ref
      .read(actionPlansNotifierProvider.notifier)
      .deleteAction(actionId: action.id, bookId: action.bookId!);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アクションを削除しました')),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDueDate(BuildContext context, DateTime dueDate) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatShortDate(dueDate);
}
