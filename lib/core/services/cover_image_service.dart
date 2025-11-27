import 'package:dio/dio.dart';

class CoverImageService {
  CoverImageService([Dio? client]) : _client = client ?? Dio();

  final Dio _client;

  Future<String?> fetchCoverImage(String? isbn) async {
    if (isbn == null || isbn.isEmpty) {
      return null;
    }

    isbn = isbn.replaceAll('-', '');

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
}
