import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Books, Notes, Actions, ReadingLogs],
  daos: [BookDao, NoteDao, ActionDao, ReadingLogDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'book_memoly.db'));
    return NativeDatabase(file);
  });
}

@DriftAccessor(tables: [Books])
class BookDao extends DatabaseAccessor<AppDatabase> with _$BookDaoMixin {
  BookDao(AppDatabase db) : super(db);

  Future<int> insertBook(BooksCompanion entry) => into(books).insert(entry);

  Future<List<BookRow>> getAllBooks() => select(books).get();

  Stream<List<BookRow>> watchAllBooks() => select(books).watch();
}

@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(AppDatabase db) : super(db);

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<List<NoteRow>> getNotesForBook(int bookId) {
    return (select(notes)..where((tbl) => tbl.bookId.equals(bookId))).get();
  }
}

@DriftAccessor(tables: [Actions])
class ActionDao extends DatabaseAccessor<AppDatabase> with _$ActionDaoMixin {
  ActionDao(AppDatabase db) : super(db);

  Future<int> insertAction(ActionsCompanion entry) =>
      into(actions).insert(entry);

  Future<List<ActionRow>> getPendingActions() {
    return (select(actions)..where((tbl) => tbl.status.equals('pending')))
        .get();
  }
}

@DriftAccessor(tables: [ReadingLogs])
class ReadingLogDao extends DatabaseAccessor<AppDatabase>
    with _$ReadingLogDaoMixin {
  ReadingLogDao(AppDatabase db) : super(db);

  Future<int> insertLog(ReadingLogsCompanion entry) =>
      into(readingLogs).insert(entry);

  Future<List<ReadingLogRow>> getLogsForBook(int bookId) {
    return (select(readingLogs)..where((tbl) => tbl.bookId.equals(bookId)))
        .get();
  }
}
