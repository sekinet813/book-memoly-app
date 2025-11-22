import 'package:drift/drift.dart';

class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get googleBooksId => text()();
  TextColumn get title => text()();
  TextColumn get authors => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get publishedDate => text().nullable()();
  IntColumn get pageCount => integer().nullable()();
  IntColumn get status => integer()(); // 0: unread, 1: reading, 2: finished
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer()();
  TextColumn get content => text()();
  IntColumn get pageNumber => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
