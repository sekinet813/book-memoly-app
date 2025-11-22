import 'dart:async';

import 'package:drift/drift.dart';

/// In-memory stand-in for the Drift database until code generation is wired up.
class AppDatabase {
  AppDatabase({QueryExecutor? executor}) {
    books = BookDao(this);
    notes = NoteDao(this);
    actions = ActionDao(this);
    readingLogs = ReadingLogDao(this);

    _emitBookSnapshot();
  }

  AppDatabase.forTesting(QueryExecutor executor) : this(executor: executor);

  late final BookDao books;
  late final NoteDao notes;
  late final ActionDao actions;
  late final ReadingLogDao readingLogs;

  final _bookRows = <BookRow>[];
  final _noteRows = <NoteRow>[];
  final _actionRows = <ActionRow>[];
  final _readingLogRows = <ReadingLogRow>[];

  int _bookId = 0;
  int _noteId = 0;
  int _actionId = 0;
  int _readingLogId = 0;

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
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.description,
    this.thumbnailUrl,
    this.publishedDate,
    this.pageCount,
    this.status = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String googleBooksId;
  final String title;
  final String? authors;
  final String? description;
  final String? thumbnailUrl;
  final String? publishedDate;
  final int? pageCount;
  int status;
  final DateTime createdAt;
  DateTime updatedAt;
}

class NoteRow {
  NoteRow({
    required this.id,
    required this.bookId,
    required this.content,
    this.pageNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final int bookId;
  final String content;
  final int? pageNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ActionRow {
  ActionRow({
    required this.id,
    this.bookId,
    required this.title,
    this.description,
    this.dueDate,
    this.status = 'pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final int? bookId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ReadingLogRow {
  ReadingLogRow({
    required this.id,
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
  final int bookId;
  final int? startPage;
  final int? endPage;
  final int? durationMinutes;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BooksCompanion {
  const BooksCompanion({
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.description,
    this.thumbnailUrl,
    this.publishedDate,
    this.pageCount,
    this.status = const Value(0),
  });

  const BooksCompanion.insert({
    required this.googleBooksId,
    required this.title,
    this.authors,
    this.description,
    this.thumbnailUrl,
    this.publishedDate,
    this.pageCount,
    this.status = const Value(0),
  });

  final String googleBooksId;
  final String title;
  final Value<String?>? authors;
  final Value<String?>? description;
  final Value<String?>? thumbnailUrl;
  final Value<String?>? publishedDate;
  final Value<int?>? pageCount;
  final Value<int> status;
}

class NotesCompanion {
  const NotesCompanion({
    required this.bookId,
    required this.content,
    this.pageNumber,
  });

  const NotesCompanion.insert({
    required this.bookId,
    required this.content,
    this.pageNumber,
  });

  final int bookId;
  final String content;
  final Value<int?>? pageNumber;
}

class ActionsCompanion {
  const ActionsCompanion({
    this.bookId,
    required this.title,
    this.description,
    this.dueDate,
    this.status = const Value('pending'),
  });

  const ActionsCompanion.insert({
    this.bookId,
    required this.title,
    this.description,
    this.dueDate,
    this.status = const Value('pending'),
  });

  final Value<int?>? bookId;
  final String title;
  final Value<String?>? description;
  final Value<DateTime?>? dueDate;
  final Value<String> status;
}

class ReadingLogsCompanion {
  const ReadingLogsCompanion({
    required this.bookId,
    this.startPage,
    this.endPage,
    this.durationMinutes,
  });

  const ReadingLogsCompanion.insert({
    required this.bookId,
    this.startPage,
    this.endPage,
    this.durationMinutes,
  });

  final int bookId;
  final Value<int?>? startPage;
  final Value<int?>? endPage;
  final Value<int?>? durationMinutes;
}

class BookDao {
  BookDao(this.db);

  final AppDatabase db;

  Future<int> insertBook(BooksCompanion entry) async {
    final newId = ++db._bookId;
    final row = BookRow(
      id: newId,
      googleBooksId: entry.googleBooksId,
      title: entry.title,
      authors: entry.authors?.value,
      description: entry.description?.value,
      thumbnailUrl: entry.thumbnailUrl?.value,
      publishedDate: entry.publishedDate?.value,
      pageCount: entry.pageCount?.value,
      status: entry.status.value,
    );

    db._bookRows.add(row);
    db._notifyBooksChanged();
    return newId;
  }

  Future<List<BookRow>> getAllBooks() async {
    return List.unmodifiable(db._bookRows);
  }

  Stream<List<BookRow>> watchAllBooks() => db._bookStream;

  Future<BookRow?> getBookByGoogleId(String googleBooksId) async {
    try {
      return db._bookRows
          .firstWhere((row) => row.googleBooksId == googleBooksId);
    } catch (_) {
      return null;
    }
  }

  Stream<BookRow?> watchBookByGoogleId(String googleBooksId) {
    return db._bookStream.map((books) {
      for (final book in books) {
        if (book.googleBooksId == googleBooksId) {
          return book;
        }
      }
      return null;
    });
  }

  Future<int> updateBookStatus(String googleBooksId, int status) async {
    final book = await getBookByGoogleId(googleBooksId);
    if (book == null) {
      return 0;
    }

    book.status = status;
    book.updatedAt = DateTime.now();
    db._notifyBooksChanged();
    return 1;
  }
}

class NoteDao {
  NoteDao(this.db);

  final AppDatabase db;

  Future<int> insertNote(NotesCompanion entry) async {
    final newId = ++db._noteId;
    db._noteRows.add(
      NoteRow(
        id: newId,
        bookId: entry.bookId,
        content: entry.content,
        pageNumber: entry.pageNumber?.value,
      ),
    );

    return newId;
  }

  Future<List<NoteRow>> getNotesForBook(int bookId) async {
    return db._noteRows.where((note) => note.bookId == bookId).toList();
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
        bookId: entry.bookId?.value,
        title: entry.title,
        description: entry.description?.value,
        dueDate: entry.dueDate?.value,
        status: entry.status.value,
      ),
    );

    return newId;
  }

  Future<List<ActionRow>> getPendingActions() async {
    return db._actionRows.where((action) => action.status == 'pending').toList();
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
        bookId: entry.bookId,
        startPage: entry.startPage?.value,
        endPage: entry.endPage?.value,
        durationMinutes: entry.durationMinutes?.value,
      ),
    );

    return newId;
  }

  Future<List<ReadingLogRow>> getLogsForBook(int bookId) async {
    return db._readingLogRows
        .where((log) => log.bookId == bookId)
        .toList(growable: false);
  }
}
