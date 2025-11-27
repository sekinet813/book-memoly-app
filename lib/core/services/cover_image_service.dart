import 'package:dio/dio.dart';

class CoverImageService {
  CoverImageService([Dio? client]) : _client = client ?? Dio();

  final Dio _client;

  Future<String?> fetchCoverImage(String bookId) async {
    final isbn = bookId.replaceAll('-', '');

    if (!_isValidIsbn(isbn)) {
      return null;
    }

    try {
      final response = await _client.get(
        'https://api.openbd.jp/v1/get',
        queryParameters: {'isbn': isbn},
        options: Options(responseType: ResponseType.json),
      );

      final data = response.data;

      if (data is! List || data.isEmpty) {
        return null;
      }

      final first = data.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final summary = first['summary'];
      if (summary is! Map<String, dynamic>) {
        return null;
      }

      final cover = summary['cover'];
      if (cover is String && cover.isNotEmpty) {
        return cover;
      }
    } on DioException catch (e) {
      // サーバーからカバー画像が取得できない場合は何もしない
      if (e.type == DioExceptionType.cancel ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return null;
      }
      rethrow;
    }

    return null;
  }

  bool _isValidIsbn(String isbn) {
    return RegExp(r'^\\d{9,13}\\$').hasMatch(isbn);
  }
}
