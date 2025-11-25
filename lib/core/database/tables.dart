import 'package:drift/drift.dart';
import '../models/goal.dart';

@DataClassName('BookRow')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get googleBooksId => text()();
  TextColumn get title => text()();
  TextColumn get authors => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get publishedDate => text().nullable()();
  IntColumn get pageCount => integer().nullable()();
  IntColumn get status => integer()
      .withDefault(const Constant(0))(); // 0: unread, 1: reading, 2: finished
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('NoteRow')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  IntColumn get pageNumber => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ActionRow')
class Actions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  IntColumn get bookId => integer()
      .nullable()
      .references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get noteId => integer()
      .nullable()
      .references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending, done, skipped
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ReadingLogRow')
class ReadingLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get startPage => integer().nullable()();
  IntColumn get endPage => integer().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GoalRow')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get period => text()(); // monthly, yearly
  IntColumn get year => integer()();
  IntColumn get month => integer().nullable()();
  TextColumn get targetType => text()(); // pages, books
  IntColumn get targetValue => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BookTagRow')
class BookTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer()
      .references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer()
      .references(Tags, #id, onDelete: KeyAction.cascade)();
}

@DataClassName('NoteTagRow')
class NoteTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer()
      .references(Notes, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer()
      .references(Tags, #id, onDelete: KeyAction.cascade)();
}
