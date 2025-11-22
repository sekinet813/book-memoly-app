import 'package:freezed_annotation/freezed_annotation.dart';

part 'memo.freezed.dart';
part 'memo.g.dart';

@freezed
class Memo with _$Memo {
  const factory Memo({
    required String id,
    required String bookId,
    required String content,
    int? pageNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Memo;

  factory Memo.fromJson(Map<String, dynamic> json) => _$MemoFromJson(json);
}
