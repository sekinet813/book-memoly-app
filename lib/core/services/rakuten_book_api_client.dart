import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../shared/config/supabase_config.dart';
import '../../shared/constants/app_constants.dart';
import '../models/rakuten/rakuten_book.dart';

final rakutenBooksDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Content-Type': 'application/json',
      },
    ),
  );
});

final rakutenBooksApiClientProvider = Provider<RakutenBooksApiClient>((ref) {
  final dio = ref.read(rakutenBooksDioProvider);
  final config = SupabaseConfig.fromEnvironment();
  return RakutenBooksApiClient(dio, config);
});

class RakutenBooksApiClient {
  RakutenBooksApiClient(this._dio, this._config);

  final Dio _dio;
  final SupabaseConfig _config;

  Future<RakutenBooksResponse> search({
    required String query,
    required RakutenSearchType searchType,
    int hits = 20,
  }) async {
    if (!_config.isValid) {
      throw const RakutenBooksApiException(
        'Supabase configuration missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY to use Rakuten Books API.',
      );
    }

    final functionsBaseUrl = _config.functionsBaseUrl;
    if (functionsBaseUrl.isEmpty) {
      throw const RakutenBooksApiException(
        'Supabase Functions URL could not be determined. Set SUPABASE_FUNCTION_URL or a valid SUPABASE_URL.',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$functionsBaseUrl${AppConstants.rakutenBooksFunctionPath}',
        data: {
          'query': query,
          'searchType': searchType.name,
          'hits': hits,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.supabaseAnonKey}',
          },
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const RakutenBooksApiException('Empty response body from Rakuten Books edge function');
      }

      return RakutenBooksResponse.fromJson(data);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapDioError(error), stackTrace);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RakutenBooksApiException(
          'Failed to fetch books from Rakuten Books API.',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  RakutenBooksApiException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RakutenBooksApiException(
          'Rakuten Books request timed out. Please try again.',
          statusCode: 408,
        );
      case DioExceptionType.badResponse:
        return RakutenBooksApiException(
          'Rakuten Books API returned an error response.',
          statusCode: statusCode,
          error: error.response?.data,
        );
      case DioExceptionType.cancel:
        return const RakutenBooksApiException('Rakuten Books request was cancelled.');
      case DioExceptionType.unknown:
      case DioExceptionType.connectionError:
        return RakutenBooksApiException(
          'Network error while contacting Rakuten Books API.',
          statusCode: statusCode,
          error: error.error,
        );
      case DioExceptionType.badCertificate:
        return const RakutenBooksApiException(
          'Certificate verification failed when contacting Rakuten Books API.',
        );
    }
  }
}
