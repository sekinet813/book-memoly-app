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
