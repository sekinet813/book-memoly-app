import 'package:book_memoly_app/core/database/app_database.dart';
import 'package:book_memoly_app/core/models/book.dart';
import 'package:book_memoly_app/core/repositories/local_database_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalDatabaseRepository repository;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = LocalDatabaseRepository(db, userId: 'test-user-id');
  });

  tearDown(() async {
    await db.close();
  });

  Book createBook() {
    return const Book(
      id: 'google-books-id',
      title: 'Test Book',
      authors: 'Author',
      pageCount: 120,
    );
  }

  test('saveBook inserts book and prevents duplicates', () async {
    final inserted = await repository.saveBook(
      createBook(),
      status: BookStatus.reading,
    );

    expect(inserted, isTrue);

    final insertedRow = await repository.findBookByGoogleId('google-books-id');
    expect(insertedRow, isNotNull);
    expect(insertedRow!.status, BookStatus.reading.toDbValue);

    final secondAttempt = await repository.saveBook(
      createBook(),
      status: BookStatus.finished,
    );

    expect(secondAttempt, isFalse);

    final allBooks = await repository.getAllBooks();
    expect(allBooks.length, 1);
  });

  test('updateBookStatus updates existing book status', () async {
    await repository.saveBook(createBook());

    await repository.updateBookStatus('google-books-id', BookStatus.finished);

    final updated = await repository.findBookByGoogleId('google-books-id');
    expect(updated?.status, BookStatus.finished.toDbValue);
  });

  test('addReadingLog stores logs for aggregation', () async {
    await repository.saveBook(createBook());
    final book = await repository.findBookByGoogleId('google-books-id');

    expect(book, isNotNull);

    await repository.addReadingLog(
      bookId: book!.id,
      pagesRead: 30,
      durationMinutes: 25,
    );

    final logs = await repository.getReadingLogs();

    expect(logs.length, 1);
    expect(logs.first.bookId, book.id);
    expect((logs.first.endPage ?? 0) - (logs.first.startPage ?? 0), 30);
    expect(logs.first.durationMinutes, 25);
  });
}
