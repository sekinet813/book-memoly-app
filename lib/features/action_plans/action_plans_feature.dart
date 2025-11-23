import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';

enum ActionStatusFilter { all, pending, done }

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
    this.statusFilter = ActionStatusFilter.all,
    this.selectedBookId,
    this.isLoadingBooks = false,
  });

  final List<BookRow> books;
  final AsyncValue<List<ActionRow>> actions;
  final List<NoteRow> notes;
  final ActionStatusFilter statusFilter;
  final int? selectedBookId;
  final bool isLoadingBooks;

  ActionPlansState copyWith({
    List<BookRow>? books,
    AsyncValue<List<ActionRow>>? actions,
    List<NoteRow>? notes,
    ActionStatusFilter? statusFilter,
    int? selectedBookId,
    bool? isLoadingBooks,
  }) {
    return ActionPlansState(
      books: books ?? this.books,
      actions: actions ?? this.actions,
      notes: notes ?? this.notes,
      statusFilter: statusFilter ?? this.statusFilter,
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
          statusFilter: ActionStatusFilter.all,
          isLoadingBooks: true,
        ));

  final LocalDatabaseRepository _repository;

  Future<void> loadBooks({int? initialBookId}) async {
    state = state.copyWith(isLoadingBooks: true);

    try {
      final books = await _repository.getAllBooks();
      final selectedBookId =
          initialBookId ?? (books.isNotEmpty ? books.first.id : null);

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
    DateTime? remindAt,
    int? noteId,
  }) async {
    await _repository.addAction(
      bookId: bookId,
      title: title,
      description: description,
      dueDate: dueDate,
      remindAt: remindAt,
      noteId: noteId,
    );
    await loadActionsForBook(bookId);
  }

  void setStatusFilter(ActionStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  Future<void> updateAction({
    required int actionId,
    required int bookId,
    required String title,
    String? description,
    DateTime? dueDate,
    Value<DateTime?> remindAt = const Value.absent(),
    String? status,
    int? noteId,
  }) async {
    await _repository.updateAction(
      actionId: actionId,
      title: title,
      description: description,
      dueDate: dueDate,
      remindAt: remindAt,
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

  Future<void> updateReminder(
      ActionRow action, Value<DateTime?> remindAt) async {
    if (action.bookId == null) {
      return;
    }

    await _repository.updateAction(
      actionId: action.id,
      title: action.title,
      description: action.description,
      dueDate: action.dueDate,
      remindAt: remindAt,
      status: action.status,
      noteId: action.noteId,
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
              _StatusFilterRow(state: state),
              const SizedBox(height: 8),
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

class _StatusFilterRow extends ConsumerWidget {
  const _StatusFilterRow({required this.state});

  final ActionPlansState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ActionStatusFilter.values.map((filter) {
          final isSelected = state.statusFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_statusFilterLabel(filter)),
              selected: isSelected,
              onSelected: (_) => ref
                  .read(actionPlansNotifierProvider.notifier)
                  .setStatusFilter(filter),
            ),
          );
        }).toList(),
      ),
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
        final filteredActions = actions
            .where((action) => _matchesFilter(action, state.statusFilter))
            .toList();

        if (filteredActions.isEmpty) {
          final message = switch (state.statusFilter) {
            ActionStatusFilter.pending => '未完了のアクションはありません',
            ActionStatusFilter.done => '完了済みのアクションはありません',
            ActionStatusFilter.all => 'この本のアクションはまだありません',
          };

          return _InfoCard(
            icon: Icons.checklist_rtl,
            message: message,
          );
        }

        return ListView.separated(
          itemCount: filteredActions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final action = filteredActions[index];
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
    final theme = Theme.of(context);
    final note = action.noteId != null
        ? notes.firstWhere(
            (n) => n.id == action.noteId,
            orElse: () => NoteRow(
              id: -1,
              userId: action.userId,
              bookId: action.bookId ?? -1,
              content: '',
            ),
          )
        : null;
    final isLinkedToNote =
        note != null && note.id != -1 && note.content.isNotEmpty;
    final isDone = action.status == 'done';
    final isOverdue =
        action.dueDate != null && action.dueDate!.isBefore(DateTime.now());
    final isReminderDue =
        action.remindAt != null && action.remindAt!.isBefore(DateTime.now());

    Future<void> _selectReminder() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: action.remindAt ?? action.dueDate ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (picked == null) {
        return;
      }

      await ref
          .read(actionPlansNotifierProvider.notifier)
          .updateReminder(action, Value(picked));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('リマインドを ${_formatDueDate(context, picked)} に更新しました'),
          ),
        );
      }
    }

    Future<void> _clearReminder() async {
      await ref
          .read(actionPlansNotifierProvider.notifier)
          .updateReminder(action, const Value<DateTime?>(null));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リマインドを解除しました')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isDone,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      if (action.description?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            action.description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              isDone ? Icons.check_circle : Icons.timelapse,
                              color: isDone
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                            ),
                            label: Text(isDone ? '完了' : '進行中'),
                            backgroundColor:
                                isDone ? Colors.green[50] : Colors.orange[50],
                          ),
                          if (action.dueDate != null)
                            InputChip(
                              avatar: const Icon(Icons.event),
                              label: Text(
                                  _formatDueDate(context, action.dueDate!)),
                              backgroundColor:
                                  isOverdue ? Colors.red[50] : Colors.grey[200],
                            ),
                          if (action.remindAt != null)
                            InputChip(
                              avatar: const Icon(Icons.alarm),
                              label: Text(
                                  _formatDueDate(context, action.remindAt!)),
                              backgroundColor: isReminderDue
                                  ? Colors.amber[50]
                                  : Colors.blueGrey[50],
                            ),
                          if (isLinkedToNote)
                            InputChip(
                              avatar: const Icon(Icons.note_alt_outlined),
                              label: Text(
                                note.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _ActionMenu(action: action),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isDone)
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('完了'),
                    onPressed: () => ref
                        .read(actionPlansNotifierProvider.notifier)
                        .toggleStatus(action, true),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('未完了に戻す'),
                    onPressed: () => ref
                        .read(actionPlansNotifierProvider.notifier)
                        .toggleStatus(action, false),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: Text(action.remindAt == null ? 'リマインド設定' : 'リマインド変更'),
                  onPressed: _selectReminder,
                ),
                if (action.remindAt != null)
                  IconButton(
                    tooltip: 'リマインドを解除',
                    icon: const Icon(Icons.alarm_off),
                    onPressed: _clearReminder,
                  ),
              ],
            ),
            if (isReminderDue && !isDone)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'リマインドの時間になりました。進捗を確認しましょう。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
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
  DateTime? remindAt = action?.remindAt;
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

          Future<void> pickReminderDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: remindAt ?? dueDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );

            if (picked != null) {
              setState(() {
                remindAt = picked;
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            remindAt == null
                                ? 'リマインド: 未設定'
                                : 'リマインド: ${_formatDueDate(context, remindAt!)}',
                          ),
                        ),
                        if (remindAt != null)
                          IconButton(
                            tooltip: 'リマインドをクリア',
                            onPressed: () {
                              setState(() {
                                remindAt = null;
                              });
                            },
                            icon: const Icon(Icons.alarm_off),
                          ),
                        TextButton.icon(
                          onPressed: pickReminderDate,
                          icon: const Icon(Icons.alarm),
                          label: const Text('リマインド'),
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
      remindAt: remindAt,
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
      remindAt: Value(remindAt),
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

String _statusFilterLabel(ActionStatusFilter filter) {
  switch (filter) {
    case ActionStatusFilter.all:
      return 'すべて';
    case ActionStatusFilter.pending:
      return '未完了';
    case ActionStatusFilter.done:
      return '完了済み';
  }
}

bool _matchesFilter(ActionRow action, ActionStatusFilter filter) {
  switch (filter) {
    case ActionStatusFilter.all:
      return true;
    case ActionStatusFilter.pending:
      return action.status != 'done';
    case ActionStatusFilter.done:
      return action.status == 'done';
  }
}
