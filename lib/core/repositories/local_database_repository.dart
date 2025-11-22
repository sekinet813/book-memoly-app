import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/book.dart';

class LocalDatabaseRepository {
  LocalDatabaseRepository(this.db)
      : books = BookDao(db),
        notes = NoteDao(db),
        actions = ActionDao(db),
        readingLogs = ReadingLogDao(db);

  final AppDatabase db;
  final BookDao books;
  final NoteDao notes;
  final ActionDao actions;
  final ReadingLogDao readingLogs;

  Future<List<BookRow>> getAllBooks() {
    return books.getAllBooks();
  }

  Future<List<NoteRow>> getNotesForBook(int bookId) {
    return notes.getNotesForBook(bookId);
  }

  Future<int> addNote({
    required int bookId,
    required String content,
    int? pageNumber,
  }) {
    return notes.insertNote(
      NotesCompanion.insert(
        bookId: bookId,
        content: content,
        pageNumber: Value(pageNumber),
      ),
    );
  }

  Future<bool> updateNote({
    required int noteId,
    required String content,
    int? pageNumber,
  }) async {
    final updated = await notes.updateNote(
      noteId: noteId,
      content: content,
      pageNumber: pageNumber,
    );

    return updated > 0;
  }

  Future<bool> deleteNote(int noteId) async {
    final deleted = await notes.deleteNote(noteId);
    return deleted > 0;
  }

  Future<bool> saveBook(
    Book book, {
    BookStatus status = BookStatus.unread,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final existing = await books.getBookByGoogleId(book.id);
    if (existing != null) {
      return false;
    }

    await books.insertBook(
      BooksCompanion.insert(
        googleBooksId: book.id,
        title: book.title,
        authors: Value(book.authors),
        description: Value(book.description),
        thumbnailUrl: Value(book.thumbnailUrl),
        publishedDate: Value(book.publishedDate),
        pageCount: Value(book.pageCount),
        status: Value(status.toDbValue),
        startedAt: Value(startedAt),
        finishedAt: Value(finishedAt),
      ),
    );

    return true;
  }

  Future<BookRow?> findBookByGoogleId(String googleBooksId) {
    return books.getBookByGoogleId(googleBooksId);
  }

  Stream<BookRow?> watchBookByGoogleId(String googleBooksId) {
    return books.watchBookByGoogleId(googleBooksId);
  }

  Future<void> updateBookStatus(String googleBooksId, BookStatus status) {
    return books.updateBookStatus(googleBooksId, status.toDbValue);
  }

  Future<void> updateBookReadingInfo(
    String googleBooksId, {
    required BookStatus status,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return books.updateBookReadingInfo(
      googleBooksId,
      status: status.toDbValue,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }

  /// Seeds the database with sample data and returns what was inserted to
  /// verify SELECT/INSERT flow works end-to-end.
  Future<SampleDataResult> insertAndReadSampleData() async {
    final bookId = await books.insertBook(
      BooksCompanion.insert(
        googleBooksId: 'sample-google-books-id',
        title: 'Sample Drift Book',
        authors: const Value('Sample Author'),
      ),
    );

    await notes.insertNote(
      NotesCompanion.insert(
        bookId: bookId,
        content: 'This is a sample note for drift verification.',
        pageNumber: const Value(12),
      ),
    );

    await actions.insertAction(
      ActionsCompanion.insert(
        title: 'Capture insights from sample book',
        bookId: Value(bookId),
        status: const Value('pending'),
      ),
    );

    await readingLogs.insertLog(
      ReadingLogsCompanion.insert(
        bookId: bookId,
        startPage: const Value(1),
        endPage: const Value(18),
        durationMinutes: const Value(25),
      ),
    );

    final booksResult = await books.getAllBooks();
    final notesResult = await notes.getNotesForBook(bookId);
    final actionsResult = await actions.getPendingActions();
    final logsResult = await readingLogs.getLogsForBook(bookId);

    return SampleDataResult(
      book: booksResult.firstWhere((row) => row.id == bookId),
      notes: notesResult,
      actions: actionsResult,
      readingLogs: logsResult,
    );
  }
}

class SampleDataResult {
  SampleDataResult({
    required this.book,
    required this.notes,
    required this.actions,
    required this.readingLogs,
  });

  final BookRow book;
  final List<NoteRow> notes;
  final List<ActionRow> actions;
  final List<ReadingLogRow> readingLogs;
}
