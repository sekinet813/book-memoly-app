import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/book.dart';

class LocalDatabaseRepository {
  LocalDatabaseRepository(this.db, {required this.userId})
      : books = BookDao(db),
        notes = NoteDao(db),
        actions = ActionDao(db),
        readingLogs = ReadingLogDao(db),
        tags = TagDao(db);

  final AppDatabase db;
  final BookDao books;
  final NoteDao notes;
  final ActionDao actions;
  final ReadingLogDao readingLogs;
  final TagDao tags;
  final String userId;

  Future<List<BookRow>> getAllBooks() {
    return books.getAllBooks(userId);
  }

  Future<List<NoteRow>> getNotesForBook(int bookId) {
    return notes.getNotesForBook(userId, bookId);
  }

  Future<List<NoteRow>> getAllNotes() {
    return notes.getAllNotes(userId);
  }

  Future<List<TagRow>> getTagsForBook(int bookId) {
    return tags.getTagsForBook(userId, bookId);
  }

  Future<Map<int, List<TagRow>>> getTagsForBooks(List<int> bookIds) async {
    final result = <int, List<TagRow>>{};
    for (final bookId in bookIds) {
      result[bookId] = await getTagsForBook(bookId);
    }
    return result;
  }

  Future<List<TagRow>> getTagsForNote(int noteId) {
    return tags.getTagsForNote(userId, noteId);
  }

  Future<Map<int, List<TagRow>>> getTagsForNotes(List<int> noteIds) async {
    final result = <int, List<TagRow>>{};
    for (final noteId in noteIds) {
      result[noteId] = await getTagsForNote(noteId);
    }
    return result;
  }

  Future<List<ActionRow>> getActionsForBook(int bookId) {
    return actions.getActionsForBook(userId, bookId);
  }

  Future<List<ActionRow>> getAllActions() {
    return actions.getAllActions(userId);
  }

  Future<List<ReadingLogRow>> getAllReadingLogs() {
    return readingLogs.getAllLogs(userId);
  }

  Future<void> upsertBookFromRemote(BookRow book) async {
    await books.upsertFromRemote(book);
  }

  Future<void> upsertNoteFromRemote(NoteRow note) async {
    await notes.upsertFromRemote(note);
  }

  Future<void> upsertActionFromRemote(ActionRow action) async {
    await actions.upsertFromRemote(action);
  }

  Future<void> upsertReadingLogFromRemote(ReadingLogRow log) async {
    await readingLogs.upsertFromRemote(log);
  }

  Future<void> setTagsForBook({
    required int bookId,
    required List<int> tagIds,
  }) {
    return tags.setTagsForBook(userId, bookId, tagIds);
  }

  Future<void> setTagsForNote({
    required int noteId,
    required List<int> tagIds,
  }) {
    return tags.setTagsForNote(userId, noteId, tagIds);
  }

  Future<List<TagRow>> getAllTags() {
    return tags.getAllTags(userId);
  }

  Future<int> createTag(String name) {
    return tags.insertTag(
      TagsCompanion.insert(userId: userId, name: name),
    );
  }

  Future<bool> updateTag({required int tagId, required String name}) async {
    final updated =
        await tags.updateTag(userId: userId, tagId: tagId, name: name);
    return updated > 0;
  }

  Future<bool> deleteTag(int tagId) async {
    final deleted = await tags.deleteTag(userId, tagId);
    return deleted > 0;
  }

  Future<int> addNote({
    required int bookId,
    required String content,
    int? pageNumber,
  }) {
    return notes.insertNote(
      NotesCompanion.insert(
        userId: userId,
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
      userId: userId,
      noteId: noteId,
      content: content,
      pageNumber: pageNumber,
    );

    return updated > 0;
  }

  Future<bool> deleteNote(int noteId) async {
    final deleted = await notes.deleteNote(userId, noteId);
    return deleted > 0;
  }

  Future<int> addAction({
    required int bookId,
    required String title,
    String? description,
    DateTime? dueDate,
    DateTime? remindAt,
    int? noteId,
  }) {
    return actions.insertAction(
      ActionsCompanion.insert(
        userId: userId,
        bookId: Value(bookId),
        noteId: Value(noteId),
        title: title,
        description: Value(description),
        dueDate: Value(dueDate),
        remindAt: Value(remindAt),
      ),
    );
  }

  Future<bool> updateAction({
    required int actionId,
    required String title,
    String? description,
    DateTime? dueDate,
    Value<DateTime?>? remindAt,
    String? status,
    int? noteId,
  }) async {
    final updated = await actions.updateAction(
      userId: userId,
      actionId: actionId,
      title: title,
      description: description,
      dueDate: dueDate,
      remindAt: remindAt,
      status: status,
      noteId: noteId,
    );

    return updated > 0;
  }

  Future<bool> updateActionStatus({
    required int actionId,
    required String status,
  }) async {
    final updated = await actions.updateAction(
      userId: userId,
      actionId: actionId,
      status: status,
    );
    return updated > 0;
  }

  Future<bool> deleteAction(int actionId) async {
    final deleted = await actions.deleteAction(userId, actionId);
    return deleted > 0;
  }

  Future<List<LocalSearchResult>> searchBooksAndNotes(
    String keyword, {
    BookStatus? statusFilter,
    Set<int>? tagIds,
  }) async {
    final trimmedKeyword = keyword.trim();
    final hasTagFilter = tagIds != null && tagIds.isNotEmpty;
    final activeTagIds = tagIds ?? const <int>{};

    if (trimmedKeyword.isEmpty && !hasTagFilter) {
      return const [];
    }

    final lowerKeyword = trimmedKeyword.toLowerCase();
    final allBooks = await getAllBooks();
    final allNotes = await getAllNotes();
    final bookTagsMap =
        await getTagsForBooks(allBooks.map((b) => b.id).toList());
    final noteTagsMap =
        await getTagsForNotes(allNotes.map((n) => n.id).toList());

    final results = <LocalSearchResult>[];

    for (final book in allBooks) {
      if (statusFilter != null && book.status != statusFilter.toDbValue) {
        continue;
      }

      final bookTags = bookTagsMap[book.id] ?? const [];

      final matchesTitle = trimmedKeyword.isNotEmpty &&
          book.title.toLowerCase().contains(lowerKeyword);
      final matchesAuthors = trimmedKeyword.isNotEmpty
          ? (book.authors ?? '').toLowerCase().contains(lowerKeyword)
          : false;
      final matchesDescription = trimmedKeyword.isNotEmpty
          ? (book.description ?? '').toLowerCase().contains(lowerKeyword)
          : false;

      final matchingNotes = allNotes
          .where((note) => note.bookId == book.id)
          .where((note) =>
              trimmedKeyword.isEmpty ||
              note.content.toLowerCase().contains(lowerKeyword))
          .toList();

      final matchingNoteTags = <int, List<TagRow>>{};
      for (final note in matchingNotes) {
        matchingNoteTags[note.id] = noteTagsMap[note.id] ?? const [];
      }

      final matchesTagFilter = !hasTagFilter ||
          bookTags.any((tag) => activeTagIds.contains(tag.id)) ||
          matchingNoteTags.values.any(
            (tags) => tags.any((tag) => activeTagIds.contains(tag.id)),
          );

      if (!matchesTagFilter) {
        continue;
      }

      if (matchesTitle ||
          matchesAuthors ||
          matchesDescription ||
          matchingNotes.isNotEmpty ||
          (hasTagFilter && bookTags.isNotEmpty)) {
        results.add(
          LocalSearchResult(
            book: book,
            matchingNotes: matchingNotes,
            bookTags: bookTags,
            noteTags: matchingNoteTags,
          ),
        );
      }
    }

    return results;
  }

  Future<int> addReadingLog({
    required int bookId,
    required int pagesRead,
    int? durationMinutes,
  }) {
    return readingLogs.insertLog(
      ReadingLogsCompanion.insert(
        userId: userId,
        bookId: bookId,
        startPage: const Value(0),
        endPage: Value(pagesRead),
        durationMinutes: Value(durationMinutes),
      ),
    );
  }

  Future<List<ReadingLogRow>> getReadingLogs() {
    return readingLogs.getAllLogs(userId);
  }

  Future<bool> saveBook(
    Book book, {
    BookStatus status = BookStatus.unread,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final existing = await books.getBookByGoogleId(userId, book.id);
    if (existing != null) {
      return false;
    }

    await books.insertBook(
      BooksCompanion.insert(
        userId: userId,
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
    return books.getBookByGoogleId(userId, googleBooksId);
  }

  Stream<BookRow?> watchBookByGoogleId(String googleBooksId) {
    return books.watchBookByGoogleId(userId, googleBooksId);
  }

  Future<void> updateBookStatus(String googleBooksId, BookStatus status) {
    return books.updateBookStatus(userId, googleBooksId, status.toDbValue);
  }

  Future<void> updateBookReadingInfo(
    String googleBooksId, {
    required BookStatus status,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return books.updateBookReadingInfo(
      userId,
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
        userId: userId,
        googleBooksId: 'sample-google-books-id',
        title: 'Sample Drift Book',
        authors: const Value('Sample Author'),
      ),
    );

    final noteId = await notes.insertNote(
      NotesCompanion.insert(
        userId: userId,
        bookId: bookId,
        content: 'This is a sample note for drift verification.',
        pageNumber: const Value(12),
      ),
    );

    await actions.insertAction(
      ActionsCompanion.insert(
        userId: userId,
        title: 'Capture insights from sample book',
        bookId: Value(bookId),
        noteId: Value(noteId),
        status: const Value('pending'),
      ),
    );

    await readingLogs.insertLog(
      ReadingLogsCompanion.insert(
        userId: userId,
        bookId: bookId,
        startPage: const Value(1),
        endPage: const Value(18),
        durationMinutes: const Value(25),
      ),
    );

    final booksResult = await books.getAllBooks(userId);
    final notesResult = await notes.getNotesForBook(userId, bookId);
    final actionsResult = await actions.getPendingActions(userId);
    final logsResult = await readingLogs.getLogsForBook(userId, bookId);

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

class LocalSearchResult {
  LocalSearchResult({
    required this.book,
    required this.matchingNotes,
    required this.bookTags,
    required this.noteTags,
  });

  final BookRow book;
  final List<NoteRow> matchingNotes;
  final List<TagRow> bookTags;
  final Map<int, List<TagRow>> noteTags;
}
