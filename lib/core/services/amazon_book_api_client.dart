import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../shared/config/supabase_config.dart';
import '../models/amazon/amazon_book.dart';

final amazonBooksDioProvider = Provider<Dio>((ref) {
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

final amazonBooksApiClientProvider = Provider<AmazonBooksApiClient>((ref) {
  final dio = ref.read(amazonBooksDioProvider);
  final config = SupabaseConfig.fromEnvironment();
  return AmazonBooksApiClient(dio, config);
});

class AmazonBooksApiClient {
  AmazonBooksApiClient(this._dio, this._config);

  final Dio _dio;
  final SupabaseConfig _config;

  Future<AmazonBooksResponse> search({
    required String query,
    required AmazonSearchType searchType,
    int maxResults = 20,
  }) async {
    if (!_config.isValid) {
      throw const AmazonBooksApiException(
        'Supabase configuration missing. Provide SUPABASE_URL and SUPABASE_ANON_KEY to use Amazon PA-API.',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _config.amazonPaapiUrl,
        data: {
          'query': query,
          'searchType': searchType.name,
          'maxResults': maxResults,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.supabaseAnonKey}',
          },
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const AmazonBooksApiException('Empty response body from Amazon PA-API edge function');
      }

      return AmazonBooksResponse.fromJson(data);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapDioError(error), stackTrace);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AmazonBooksApiException(
          'Failed to fetch books from Amazon PA-API.',
          error: error,
        ),
        stackTrace,
      );
    }
  }

  AmazonBooksApiException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AmazonBooksApiException(
          'Amazon PA-API request timed out. Please try again.',
          statusCode: 408,
        );
      case DioExceptionType.badResponse:
        return AmazonBooksApiException(
          'Amazon PA-API returned an error response.',
          statusCode: statusCode,
          error: error.response?.data,
        );
      case DioExceptionType.cancel:
        return const AmazonBooksApiException('Amazon PA-API request was cancelled.');
      case DioExceptionType.unknown:
      case DioExceptionType.connectionError:
        return AmazonBooksApiException(
          'Network error while contacting Amazon PA-API.',
          statusCode: statusCode,
          error: error.error,
        );
      case DioExceptionType.badCertificate:
        return const AmazonBooksApiException(
          'Certificate verification failed when contacting Amazon PA-API.',
        );
    }
  }
}
