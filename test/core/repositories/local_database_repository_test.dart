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
    repository = LocalDatabaseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Book _createBook() {
    return const Book(
      id: 'google-books-id',
      title: 'Test Book',
      authors: 'Author',
      pageCount: 120,
    );
  }

  test('saveBook inserts book and prevents duplicates', () async {
    final inserted = await repository.saveBook(
      _createBook(),
      status: BookStatus.reading,
    );

    expect(inserted, isTrue);

    final insertedRow = await repository.findBookByGoogleId('google-books-id');
    expect(insertedRow, isNotNull);
    expect(insertedRow!.status, BookStatus.reading.toDbValue);

    final secondAttempt = await repository.saveBook(
      _createBook(),
      status: BookStatus.finished,
    );

    expect(secondAttempt, isFalse);

    final allBooks = await repository.books.getAllBooks();
    expect(allBooks.length, 1);
  });

  test('updateBookStatus updates existing book status', () async {
    await repository.saveBook(_createBook());

    await repository.updateBookStatus('google-books-id', BookStatus.finished);

    final updated = await repository.findBookByGoogleId('google-books-id');
    expect(updated?.status, BookStatus.finished.toDbValue);
  });
}
