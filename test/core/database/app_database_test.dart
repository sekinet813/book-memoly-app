import 'package:book_memoly_app/core/database/app_database.dart';
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

  test('Drift can INSERT and SELECT sample data', () async {
    final result = await repository.insertAndReadSampleData();

    expect(result.book.id, greaterThan(0));
    expect(result.notes, isNotEmpty);
    expect(result.actions, isNotEmpty);
    expect(result.readingLogs, isNotEmpty);

    final fetchedNotes = await repository.getNotesForBook(result.book.id);
    expect(fetchedNotes.first.content, contains('sample note'));
  });
}
