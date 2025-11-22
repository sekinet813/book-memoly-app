import 'package:drift/drift.dart';

import '../database/app_database.dart';

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
