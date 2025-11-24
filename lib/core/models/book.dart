import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

@freezed
class Book with _$Book {
  const factory Book({
    required String id,
    required String title,
    String? authors,
    String? description,
    String? thumbnailUrl,
    String? publishedDate,
    int? pageCount,
    String? publisher,
    String? isbn,
    String? rakutenUrl,
    @Default(BookStatus.unread) BookStatus status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

enum BookStatus {
  unread,
  reading,
  finished,
}

extension BookStatusX on BookStatus {
  int get toDbValue => index;

  String get label {
    switch (this) {
      case BookStatus.unread:
        return '未読';
      case BookStatus.reading:
        return '読書中';
      case BookStatus.finished:
        return '読了';
    }
  }
}

BookStatus bookStatusFromDbValue(int value) {
  if (value < 0 || value >= BookStatus.values.length) {
    return BookStatus.unread;
  }

  return BookStatus.values[value];
}
