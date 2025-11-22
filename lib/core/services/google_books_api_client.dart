import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../shared/constants/app_constants.dart';
import '../models/google_books/google_books_volume.dart';

final googleBooksDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConstants.googleBooksApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: const {
        'Content-Type': 'application/json',
      },
    ),
  );
});

final googleBooksApiClientProvider = Provider<GoogleBooksApiClient>((ref) {
  return GoogleBooksApiClient(ref.read(googleBooksDioProvider));
});

class GoogleBooksApiClient {
  GoogleBooksApiClient(this._dio);

  final Dio _dio;

  Future<GoogleBooksVolumesResponse> searchVolumes({
    required String query,
    int maxResults = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/volumes',
        queryParameters: {
          'q': query,
          'maxResults': maxResults,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const GoogleBooksApiException('Empty response body');
      }

      return GoogleBooksVolumesResponse.fromJson(data);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapDioError(error), stackTrace);
    } catch (error, stackTrace) {
      const fallbackMessage = 'Failed to fetch books from Google Books API.';
      Error.throwWithStackTrace(
        GoogleBooksApiException(
          fallbackMessage,
          statusCode: null,
          error: error,
        ),
        stackTrace,
      );
    }
  }

  GoogleBooksApiException _mapDioError(DioException error) {
    final statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const GoogleBooksApiException(
          'Google Books API request timed out. Please try again.',
          statusCode: 408,
        );
      case DioExceptionType.badResponse:
        return GoogleBooksApiException(
          'Google Books API returned an error response.',
          statusCode: statusCode,
          error: error.response?.data,
        );
      case DioExceptionType.cancel:
        return const GoogleBooksApiException('Google Books API request was cancelled.');
      case DioExceptionType.unknown:
      case DioExceptionType.connectionError:
        return GoogleBooksApiException(
          'Network error while contacting Google Books API.',
          statusCode: statusCode,
          error: error.error,
        );
      case DioExceptionType.badCertificate:
        return const GoogleBooksApiException(
          'Certificate verification failed when contacting Google Books API.',
        );
    }
  }
}

@immutable
class GoogleBooksApiException implements Exception {
  const GoogleBooksApiException(
    this.message, {
    this.statusCode,
    this.error,
  });

  final String message;
  final int? statusCode;
  final Object? error;

  @override
  String toString() {
    final buffer = StringBuffer('GoogleBooksApiException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (error != null) {
      buffer.write(' - details: ${Error.safeToString(error)}');
    }
    return buffer.toString();
  }
}
