import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class CoverImageService {
  CoverImageService([Dio? client]) : _client = client ?? Dio();

  final Dio _client;

  Future<String?> fetchCoverImage(String? isbn) async {
    debugPrint('[CoverImageService] fetchCoverImage called with ISBN: $isbn');

    if (isbn == null || isbn.isEmpty) {
      debugPrint('[CoverImageService] ISBN is null or empty');
      return null;
    }

    isbn = isbn.replaceAll('-', '');
    debugPrint('[CoverImageService] Cleaned ISBN: $isbn');

    if (!_isValidIsbn(isbn)) {
      debugPrint('[CoverImageService] ISBN is not valid: $isbn');
      return null;
    }

    try {
      debugPrint(
          '[CoverImageService] Fetching cover image from openBD API for ISBN: $isbn');
      final response = await _client.get(
        'https://api.openbd.jp/v1/get',
        queryParameters: {'isbn': isbn},
        options: Options(responseType: ResponseType.json),
      );

      debugPrint(
          '[CoverImageService] API response status: ${response.statusCode}');
      final data = response.data;

      if (data is! List || data.isEmpty) {
        debugPrint('[CoverImageService] API response is empty or not a list');
        return null;
      }

      final first = data.first;
      if (first is! Map<String, dynamic>) {
        debugPrint('[CoverImageService] First item is not a map');
        return null;
      }

      // レスポンスの構造を詳しく確認
      debugPrint('[CoverImageService] Response keys: ${first.keys.toList()}');

      final summary = first['summary'];
      if (summary is! Map<String, dynamic>) {
        debugPrint(
            '[CoverImageService] Summary is not a map, summary type: ${summary.runtimeType}');
        debugPrint('[CoverImageService] First item content: $first');
        return null;
      }

      debugPrint('[CoverImageService] Summary keys: ${summary.keys.toList()}');
      final cover = summary['cover'];
      debugPrint(
          '[CoverImageService] Cover value: $cover (type: ${cover.runtimeType})');

      if (cover is String && cover.isNotEmpty) {
        debugPrint('[CoverImageService] Cover image URL found: $cover');
        return cover;
      } else {
        debugPrint(
            '[CoverImageService] Cover image URL is empty or not a string');
        // 他のフィールドも確認
        if (summary.containsKey('isbn')) {
          debugPrint('[CoverImageService] ISBN in summary: ${summary['isbn']}');
        }
      }
    } on DioException catch (e) {
      debugPrint('[CoverImageService] DioException: ${e.type}, ${e.message}');
      // サーバーからカバー画像が取得できない場合は何もしない
      if (e.type == DioExceptionType.cancel ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return null;
      }
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[CoverImageService] Unexpected error: $e');
      debugPrint('[CoverImageService] Stack trace: $stackTrace');
      rethrow;
    }

    debugPrint('[CoverImageService] No cover image found for ISBN: $isbn');
    return null;
  }

  bool _isValidIsbn(String isbn) {
    if (isbn.length == _isbn10Length) {
      return _isValidIsbn10(isbn);
    }

    if (isbn.length == _isbn13Length) {
      return _isValidIsbn13(isbn);
    }

    return false;
  }

  bool _isValidIsbn10(String isbn) {
    if (!RegExp('^\\d{$_isbn10BodyLength}[\\dXx]\$').hasMatch(isbn)) {
      return false;
    }

    var sum = 0;

    for (var i = 0; i < _isbn10BodyLength; i++) {
      final weight = _isbn10Length - i;
      sum += weight * int.parse(isbn[i]);
    }

    final checkDigit = isbn[_isbn10BodyLength].toUpperCase() == 'X'
        ? 10
        : int.parse(isbn[_isbn10BodyLength]);

    return (sum + checkDigit) % _isbn10Modulus == 0;
  }

  bool _isValidIsbn13(String isbn) {
    if (!RegExp('^\\d{$_isbn13Length}\$').hasMatch(isbn)) {
      return false;
    }

    var sum = 0;

    for (var i = 0; i < _isbn13BodyLength; i++) {
      final digit = int.parse(isbn[i]);
      final weight = i.isEven ? _isbn13EvenWeight : _isbn13OddWeight;
      sum += digit * weight;
    }

    final checkDigit =
        (_isbn13Modulus - (sum % _isbn13Modulus)) % _isbn13Modulus;

    return checkDigit == int.parse(isbn[_isbn13BodyLength]);
  }

  static const int _isbn10Length = 10;
  static const int _isbn10BodyLength = 9;
  static const int _isbn10Modulus = 11;
  static const int _isbn13Length = 13;
  static const int _isbn13BodyLength = 12;
  static const int _isbn13Modulus = 10;
  static const int _isbn13EvenWeight = 1;
  static const int _isbn13OddWeight = 3;

  /// 文字列からISBNを抽出します。
  /// googleBooksIdがISBNの形式（10桁または13桁の数字）の場合、それを返します。
  static String? extractIsbn(String? id) {
    if (id == null || id.isEmpty) {
      debugPrint('[CoverImageService] extractIsbn: id is null or empty');
      return null;
    }

    // ハイフンを除去
    final cleaned = id.replaceAll('-', '');
    debugPrint(
        '[CoverImageService] extractIsbn: cleaned id = $cleaned (length: ${cleaned.length})');

    // ISBN-10: 10桁（最後の桁は数字またはX）
    if (cleaned.length == 10 && RegExp(r'^\d{9}[\dXx]$').hasMatch(cleaned)) {
      debugPrint('[CoverImageService] extractIsbn: Found ISBN-10: $cleaned');
      return cleaned;
    }

    // ISBN-13: 13桁の数字
    if (cleaned.length == 13 && RegExp(r'^\d{13}$').hasMatch(cleaned)) {
      debugPrint('[CoverImageService] extractIsbn: Found ISBN-13: $cleaned');
      return cleaned;
    }

    debugPrint('[CoverImageService] extractIsbn: No ISBN found in: $id');
    return null;
  }
}
