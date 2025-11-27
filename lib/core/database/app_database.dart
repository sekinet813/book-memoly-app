import 'dart:async';

import 'package:drift/drift.dart';

import '../models/goal.dart';

/// In-memory stand-in for the Drift database until code generation is wired up.
class AppDatabase {
  AppDatabase({QueryExecutor? executor}) {
    books = BookDao(this);
    notes = NoteDao(this);
    actions = ActionDao(this);
    readingLogs = ReadingLogDao(this);
    tags = TagDao(this);
    goals = GoalDao(this);

    _emitBookSnapshot();
  }

  AppDatabase.forTesting(QueryExecutor executor) : this(executor: executor);

  late final BookDao books;
  late final NoteDao notes;
  late final ActionDao actions;
  late final ReadingLogDao readingLogs;
  late final TagDao tags;
  late final GoalDao goals;

  final _bookRows = <BookRow>[];
  final _noteRows = <NoteRow>[];
  final _actionRows = <ActionRow>[];
  final _readingLogRows = <ReadingLogRow>[];
  final _tagRows = <TagRow>[];
  final _bookTagRows = <BookTagRow>[];
  final _noteTagRows = <NoteTagRow>[];
  final _goalRows = <GoalRow>[];

  int _bookId = 0;
  int _noteId = 0;
  int _actionId = 0;
  int _readingLogId = 0;
  int _tagId = 0;
  int _bookTagId = 0;
  int _noteTagId = 0;
  int _goalId = 0;

  final _bookStreamController =
      StreamController<List<BookRow>>.broadcast(onListen: () {});

  Stream<List<BookRow>> get _bookStream => _bookStreamController.stream;

  void _emitBookSnapshot() {
    _bookStreamController.add(List.unmodifiable(_bookRows));
  }

  void _notifyBooksChanged() {
    _emitBookSnapshot();
  }

  Future<void> close() async {
    await _bookStreamController.close();
  }
}

class BookRow {
  BookRow({
    required this.id,
    required this.userId,
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.description,
    this.thumbnailUrl,
    this.publishedDate,
    this.pageCount,
    this.status = 0,
    this.startedAt,
    this.finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String userId;
  final String googleBooksId;
  final String title;
  final String? authors;
  final String? description;
  String? thumbnailUrl;
  final String? publishedDate;
  final int? pageCount;
  int status;
  DateTime? startedAt;
  DateTime? finishedAt;
  final DateTime createdAt;
  DateTime updatedAt;
}

class NoteRow {
  NoteRow({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.content,
    this.pageNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String userId;
  final int bookId;
  final String content;
  final int? pageNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ActionRow {
  ActionRow({
    required this.id,
    required this.userId,
    this.bookId,
    this.noteId,
    required this.title,
    this.description,
    this.dueDate,
    this.remindAt,
    this.status = 'pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String userId;
  final int? bookId;
  final int? noteId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? remindAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ReadingLogRow {
  ReadingLogRow({
    required this.id,
    required this.userId,
    required this.bookId,
    this.startPage,
    this.endPage,
    this.durationMinutes,
    DateTime? loggedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : loggedAt = loggedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String userId;
  final int bookId;
  final int? startPage;
  final int? endPage;
  final int? durationMinutes;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TagRow {
  TagRow({
    required this.id,
    required this.userId,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String userId;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
}

class BookTagRow {
  BookTagRow({
    required this.id,
    required this.bookId,
    required this.tagId,
  });

  final int id;
  final int bookId;
  final int tagId;
}

class NoteTagRow {
  NoteTagRow({
    required this.id,
    required this.noteId,
    required this.tagId,
  });

  final int id;
  final int noteId;
  final int tagId;
}

class GoalRow {
  GoalRow({
    required this.id,
    required this.userId,
    required this.period,
    required this.year,
    this.month,
    required this.targetType,
    required this.targetValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String userId;
  final GoalPeriod period;
  final int year;
  final int? month;
  final GoalMetric targetType;
  final int targetValue;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BooksCompanion {
  const BooksCompanion({
    required this.userId,
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.description,
    this.thumbnailUrl,
    this.publishedDate,
    this.pageCount,
    this.status = const Value(0),
    this.startedAt,
    this.finishedAt,
  });

  const BooksCompanion.insert({
    required this.userId,
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.description,
    this.thumbnailUrl,
    this.publishedDate,
    this.pageCount,
    this.status = const Value(0),
    this.startedAt,
    this.finishedAt,
  });

  final String userId;
  final String googleBooksId;
  final String title;
  final Value<String?>? authors;
  final Value<String?>? description;
  final Value<String?>? thumbnailUrl;
  final Value<String?>? publishedDate;
  final Value<int?>? pageCount;
  final Value<int> status;
  final Value<DateTime?>? startedAt;
  final Value<DateTime?>? finishedAt;
}

class NotesCompanion {
  const NotesCompanion({
    required this.userId,
    required this.bookId,
    required this.content,
    this.pageNumber,
  });

  const NotesCompanion.insert({
    required this.userId,
    required this.bookId,
    required this.content,
    this.pageNumber,
  });

  final String userId;
  final int bookId;
  final String content;
  final Value<int?>? pageNumber;
}

class ActionsCompanion {
  const ActionsCompanion({
    required this.userId,
    this.bookId,
    this.noteId,
    required this.title,
    this.description,
    this.dueDate,
    this.remindAt,
    this.status = const Value('pending'),
  });

  const ActionsCompanion.insert({
    required this.userId,
    this.bookId,
    this.noteId,
    required this.title,
    this.description,
    this.dueDate,
    this.remindAt,
    this.status = const Value('pending'),
  });

  final String userId;
  final Value<int?>? bookId;
  final Value<int?>? noteId;
  final String title;
  final Value<String?>? description;
  final Value<DateTime?>? dueDate;
  final Value<DateTime?>? remindAt;
  final Value<String> status;
}

class ReadingLogsCompanion {
  const ReadingLogsCompanion({
    required this.userId,
    required this.bookId,
    this.startPage,
    this.endPage,
    this.durationMinutes,
  });

  const ReadingLogsCompanion.insert({
    required this.userId,
    required this.bookId,
    this.startPage,
    this.endPage,
    this.durationMinutes,
  });

  final String userId;
  final int bookId;
  final Value<int?>? startPage;
  final Value<int?>? endPage;
  final Value<int?>? durationMinutes;
}

class TagsCompanion {
  const TagsCompanion({
    required this.userId,
    required this.name,
  });

  const TagsCompanion.insert({
    required this.userId,
    required this.name,
  });

  final String userId;
  final String name;
}

class GoalsCompanion {
  const GoalsCompanion({
    required this.userId,
    required this.period,
    required this.year,
    this.month,
    required this.targetType,
    required this.targetValue,
  });

  const GoalsCompanion.insert({
    required this.userId,
    required this.period,
    required this.year,
    this.month,
    required this.targetType,
    required this.targetValue,
  });

  final String userId;
  final GoalPeriod period;
  final int year;
  final Value<int?>? month;
  final GoalMetric targetType;
  final int targetValue;
}

class BookDao {
  BookDao(this.db);

  final AppDatabase db;

  Future<int> insertBook(BooksCompanion entry) async {
    final newId = ++db._bookId;
    final row = BookRow(
      id: newId,
      userId: entry.userId,
      googleBooksId: entry.googleBooksId,
      title: entry.title,
      authors: entry.authors?.value,
      description: entry.description?.value,
      thumbnailUrl: entry.thumbnailUrl?.value,
      publishedDate: entry.publishedDate?.value,
      pageCount: entry.pageCount?.value,
      status: entry.status.value,
      startedAt: entry.startedAt?.value,
      finishedAt: entry.finishedAt?.value,
    );

    db._bookRows.add(row);
    db._notifyBooksChanged();
    return newId;
  }

  Future<List<BookRow>> getAllBooks(String userId) async {
    return db._bookRows
        .where((row) => row.userId == userId)
        .toList(growable: false);
  }

  Stream<List<BookRow>> watchAllBooks(String userId) async* {
    yield await getAllBooks(userId);
    yield* db._bookStream.map(
      (books) =>
          books.where((book) => book.userId == userId).toList(growable: false),
    );
  }

  Future<BookRow?> getBookByGoogleId(
    String userId,
    String googleBooksId,
  ) async {
    try {
      return db._bookRows.firstWhere(
        (row) => row.userId == userId && row.googleBooksId == googleBooksId,
      );
    } catch (_) {
      return null;
    }
  }

  Stream<BookRow?> watchBookByGoogleId(
      String userId, String googleBooksId) async* {
    yield await getBookByGoogleId(userId, googleBooksId);
    yield* db._bookStream.map((books) {
      for (final book in books) {
        if (book.userId == userId && book.googleBooksId == googleBooksId) {
          return book;
        }
      }
      return null;
    });
  }

  Future<int> updateBookStatus(
    String userId,
    String googleBooksId,
    int status,
  ) async {
    final book = await getBookByGoogleId(userId, googleBooksId);
    if (book == null) {
      return 0;
    }

    book.status = status;
    book.updatedAt = DateTime.now();
    db._notifyBooksChanged();
    return 1;
  }

  Future<int> updateBookReadingInfo(
    String userId,
    String googleBooksId, {
    required int status,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final book = await getBookByGoogleId(userId, googleBooksId);
    if (book == null) {
      return 0;
    }

    book.status = status;
    book.startedAt = startedAt;
    book.finishedAt = finishedAt;
    book.updatedAt = DateTime.now();
    db._notifyBooksChanged();
    return 1;
  }

  Future<int> updateBookThumbnail(
    String userId,
    String googleBooksId,
    String thumbnailUrl,
  ) async {
    final book = await getBookByGoogleId(userId, googleBooksId);
    if (book == null) {
      return 0;
    }

    if (book.thumbnailUrl == thumbnailUrl) {
      return 0;
    }

    book.thumbnailUrl = thumbnailUrl;
    book.updatedAt = DateTime.now();
    db._notifyBooksChanged();
    return 1;
  }

  Future<void> upsertFromRemote(BookRow row) async {
    final index = db._bookRows
        .indexWhere((book) => book.id == row.id && book.userId == row.userId);
    if (index == -1) {
      db._bookRows.add(row);
    } else {
      db._bookRows[index] = row;
    }

    if (db._bookId < row.id) {
      db._bookId = row.id;
    }

    db._notifyBooksChanged();
  }
}

class NoteDao {
  NoteDao(this.db);

  final AppDatabase db;

  Future<List<NoteRow>> getAllNotes(String userId) async {
    return db._noteRows
        .where((row) => row.userId == userId)
        .toList(growable: false);
  }

  Future<int> insertNote(NotesCompanion entry) async {
    final newId = ++db._noteId;
    db._noteRows.add(
      NoteRow(
        id: newId,
        userId: entry.userId,
        bookId: entry.bookId,
        content: entry.content,
        pageNumber: entry.pageNumber?.value,
      ),
    );

    return newId;
  }

  Future<List<NoteRow>> getNotesForBook(String userId, int bookId) async {
    return db._noteRows
        .where((note) => note.userId == userId && note.bookId == bookId)
        .toList(growable: false);
  }

  Future<int> updateNote({
    required String userId,
    required int noteId,
    required String content,
    int? pageNumber,
  }) async {
    final index = db._noteRows
        .indexWhere((note) => note.id == noteId && note.userId == userId);
    if (index == -1) {
      return 0;
    }

    final existing = db._noteRows[index];
    db._noteRows[index] = NoteRow(
      id: existing.id,
      userId: existing.userId,
      bookId: existing.bookId,
      content: content,
      pageNumber: pageNumber,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    return 1;
  }

  Future<int> deleteNote(String userId, int noteId) async {
    final beforeLength = db._noteRows.length;
    db._noteRows
        .removeWhere((note) => note.id == noteId && note.userId == userId);
    db._noteTagRows.removeWhere((row) => row.noteId == noteId);
    return beforeLength == db._noteRows.length ? 0 : 1;
  }

  Future<void> upsertFromRemote(NoteRow row) async {
    final index = db._noteRows
        .indexWhere((note) => note.id == row.id && note.userId == row.userId);
    if (index == -1) {
      db._noteRows.add(row);
    } else {
      db._noteRows[index] = row;
    }

    if (db._noteId < row.id) {
      db._noteId = row.id;
    }
  }
}

class ActionDao {
  ActionDao(this.db);

  final AppDatabase db;

  Future<int> insertAction(ActionsCompanion entry) async {
    final newId = ++db._actionId;
    db._actionRows.add(
      ActionRow(
        id: newId,
        userId: entry.userId,
        bookId: entry.bookId?.value,
        noteId: entry.noteId?.value,
        title: entry.title,
        description: entry.description?.value,
        dueDate: entry.dueDate?.value,
        remindAt: entry.remindAt?.value,
        status: entry.status.value,
      ),
    );

    return newId;
  }

  Future<List<ActionRow>> getPendingActions(String userId) async {
    return db._actionRows
        .where(
            (action) => action.userId == userId && action.status == 'pending')
        .toList();
  }

  Future<List<ActionRow>> getAllActions(String userId) async {
    final actions = List<ActionRow>.from(
      db._actionRows.where((action) => action.userId == userId),
    )..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return actions;
  }

  Future<List<ActionRow>> getActionsForBook(String userId, int bookId) async {
    return db._actionRows
        .where((action) => action.userId == userId && action.bookId == bookId)
        .toList(growable: false);
  }

  Future<int> updateAction({
    required String userId,
    required int actionId,
    String? title,
    String? description,
    DateTime? dueDate,
    Value<DateTime?>? remindAt,
    String? status,
    int? noteId,
  }) async {
    final index = db._actionRows.indexWhere(
        (action) => action.id == actionId && action.userId == userId);
    if (index == -1) {
      return 0;
    }

    final existing = db._actionRows[index];
    db._actionRows[index] = ActionRow(
      id: existing.id,
      userId: existing.userId,
      bookId: existing.bookId,
      noteId: noteId ?? existing.noteId,
      title: title ?? existing.title,
      description: description ?? existing.description,
      dueDate: dueDate ?? existing.dueDate,
      remindAt: remindAt != null ? remindAt.value : existing.remindAt,
      status: status ?? existing.status,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    return 1;
  }

  Future<int> deleteAction(String userId, int actionId) async {
    final beforeLength = db._actionRows.length;
    db._actionRows.removeWhere(
        (action) => action.id == actionId && action.userId == userId);
    return beforeLength == db._actionRows.length ? 0 : 1;
  }

  Future<void> upsertFromRemote(ActionRow row) async {
    final index = db._actionRows.indexWhere(
      (action) => action.id == row.id && action.userId == row.userId,
    );

    if (index == -1) {
      db._actionRows.add(row);
    } else {
      db._actionRows[index] = row;
    }

    if (db._actionId < row.id) {
      db._actionId = row.id;
    }
  }
}

class ReadingLogDao {
  ReadingLogDao(this.db);

  final AppDatabase db;

  Future<int> insertLog(ReadingLogsCompanion entry) async {
    final newId = ++db._readingLogId;
    db._readingLogRows.add(
      ReadingLogRow(
        id: newId,
        userId: entry.userId,
        bookId: entry.bookId,
        startPage: entry.startPage?.value,
        endPage: entry.endPage?.value,
        durationMinutes: entry.durationMinutes?.value,
      ),
    );

    return newId;
  }

  Future<List<ReadingLogRow>> getLogsForBook(String userId, int bookId) async {
    return db._readingLogRows
        .where((log) => log.userId == userId && log.bookId == bookId)
        .toList(growable: false);
  }

  Future<List<ReadingLogRow>> getAllLogs(String userId) async {
    final logs = List<ReadingLogRow>.from(
      db._readingLogRows.where((log) => log.userId == userId),
    )..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return logs;
  }

  Future<void> upsertFromRemote(ReadingLogRow row) async {
    final index = db._readingLogRows.indexWhere(
      (log) => log.id == row.id && log.userId == row.userId,
    );

    if (index == -1) {
      db._readingLogRows.add(row);
    } else {
      db._readingLogRows[index] = row;
    }

    if (db._readingLogId < row.id) {
      db._readingLogId = row.id;
    }
  }
}

class TagDao {
  TagDao(this.db);

  final AppDatabase db;

  Future<List<TagRow>> getAllTags(String userId) async {
    return db._tagRows
        .where((tag) => tag.userId == userId)
        .toList(growable: false);
  }

  Future<int> insertTag(TagsCompanion entry) async {
    final newId = ++db._tagId;
    db._tagRows.add(
      TagRow(
        id: newId,
        userId: entry.userId,
        name: entry.name,
      ),
    );

    return newId;
  }

  Future<int> updateTag({
    required String userId,
    required int tagId,
    required String name,
  }) async {
    final index = db._tagRows
        .indexWhere((tag) => tag.id == tagId && tag.userId == userId);
    if (index == -1) {
      return 0;
    }

    final existing = db._tagRows[index];
    existing
      ..name = name
      ..updatedAt = DateTime.now();

    return 1;
  }

  Future<int> deleteTag(String userId, int tagId) async {
    final before = db._tagRows.length;
    db._tagRows.removeWhere((tag) => tag.id == tagId && tag.userId == userId);

    if (before == db._tagRows.length) {
      return 0;
    }

    db._bookTagRows.removeWhere((row) => row.tagId == tagId);
    db._noteTagRows.removeWhere((row) => row.tagId == tagId);

    return 1;
  }

  Future<void> setTagsForBook(
    String userId,
    int bookId,
    List<int> tagIds,
  ) async {
    db._bookTagRows.removeWhere(
      (row) => row.bookId == bookId && _tagBelongsToUser(row.tagId, userId),
    );

    for (final tagId in tagIds.toSet()) {
      if (!_tagBelongsToUser(tagId, userId)) {
        continue;
      }

      db._bookTagRows.add(
        BookTagRow(id: ++db._bookTagId, bookId: bookId, tagId: tagId),
      );
    }
  }

  Future<void> setTagsForNote(
    String userId,
    int noteId,
    List<int> tagIds,
  ) async {
    db._noteTagRows.removeWhere(
      (row) => row.noteId == noteId && _tagBelongsToUser(row.tagId, userId),
    );

    for (final tagId in tagIds.toSet()) {
      if (!_tagBelongsToUser(tagId, userId)) {
        continue;
      }

      db._noteTagRows.add(
        NoteTagRow(id: ++db._noteTagId, noteId: noteId, tagId: tagId),
      );
    }
  }

  Future<List<TagRow>> getTagsForBook(String userId, int bookId) async {
    final tagIds = db._bookTagRows
        .where((row) => row.bookId == bookId)
        .map((row) => row.tagId)
        .toSet();

    return db._tagRows
        .where((tag) => tag.userId == userId && tagIds.contains(tag.id))
        .toList(growable: false);
  }

  Future<List<TagRow>> getTagsForNote(String userId, int noteId) async {
    final tagIds = db._noteTagRows
        .where((row) => row.noteId == noteId)
        .map((row) => row.tagId)
        .toSet();

    return db._tagRows
        .where((tag) => tag.userId == userId && tagIds.contains(tag.id))
        .toList(growable: false);
  }

  TagRow? _findTag(int tagId) {
    try {
      return db._tagRows.firstWhere((tag) => tag.id == tagId);
    } catch (_) {
      return null;
    }
  }

  bool _tagBelongsToUser(int tagId, String userId) {
    final tag = _findTag(tagId);
    return tag?.userId == userId;
  }
}

class GoalDao {
  GoalDao(this.db);

  final AppDatabase db;

  Future<List<GoalRow>> getAllGoals(String userId) async {
    final goals = db._goalRows
        .where((goal) => goal.userId == userId)
        .toList(growable: false);

    goals.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return goals;
  }

  Future<GoalRow?> getGoalForPeriod(
    String userId,
    GoalPeriod period, {
    required int year,
    int? month,
  }) async {
    try {
      return db._goalRows.firstWhere(
        (goal) =>
            goal.userId == userId &&
            goal.period == period &&
            goal.year == year &&
            goal.month == month,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> upsertGoal(GoalsCompanion entry) async {
    final targetMonth = entry.month?.value;
    final index = db._goalRows.indexWhere(
      (goal) =>
          goal.userId == entry.userId &&
          goal.period == entry.period &&
          goal.year == entry.year &&
          goal.month == targetMonth,
    );

    if (index == -1) {
      final newId = ++db._goalId;
      db._goalRows.add(
        GoalRow(
          id: newId,
          userId: entry.userId,
          period: entry.period,
          year: entry.year,
          month: targetMonth,
          targetType: entry.targetType,
          targetValue: entry.targetValue,
        ),
      );
      return newId;
    }

    final existing = db._goalRows[index];
    db._goalRows[index] = GoalRow(
      id: existing.id,
      userId: existing.userId,
      period: existing.period,
      year: existing.year,
      month: existing.month,
      targetType: entry.targetType,
      targetValue: entry.targetValue,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    return existing.id;
  }

  Future<void> upsertFromRemote(GoalRow row) async {
    final index = db._goalRows.indexWhere(
      (goal) => goal.id == row.id && goal.userId == row.userId,
    );

    if (index == -1) {
      db._goalRows.add(row);
    } else {
      db._goalRows[index] = row;
    }

    if (db._goalId < row.id) {
      db._goalId = row.id;
    }
  }
}
