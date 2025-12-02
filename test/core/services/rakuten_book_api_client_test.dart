import 'package:book_memoly_app/core/models/rakuten/rakuten_book.dart';
import 'package:book_memoly_app/core/services/rakuten_book_api_client.dart';
import 'package:book_memoly_app/shared/config/supabase_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _PostResponder = Future<Response<Map<String, dynamic>>> Function(
  String path,
  dynamic data,
  Options? options,
);

class _StubDio extends Dio {
  _StubDio(this._onPost);

  final _PostResponder _onPost;

  @override
  Future<Response<T>> post<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await _onPost(path, data, options);
    return Response<T>(
      data: response.data as T?,
      statusCode: response.statusCode,
      requestOptions: response.requestOptions,
      statusMessage: response.statusMessage,
      headers: response.headers,
      redirects: response.redirects,
      extra: response.extra,
    );
  }
}

void main() {
  const config = SupabaseConfig(
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon-key',
    supabaseFunctionsUrl: 'https://example.functions.supabase.co/functions/v1',
  );

  test('parses successful responses into RakutenBooksResponse', () async {
    final dio = _StubDio((path, data, options) async {
      return Response(
        data: {
          'Items': [
            {
              'Item': {
                'title': 'Sample Title',
                'author': 'Author One／Author Two',
                'isbn': '1234567890',
                'itemUrl': 'https://example.com',
              },
            },
          ],
          'count': '1',
          'hits': 1,
          'page': 2,
          'pageCount': '3',
          'searchMode': 'partial',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    });

    final client = RakutenBooksApiClient(dio, config);

    final response = await client.search(
      query: 'sample',
      searchType: RakutenSearchType.keywords,
      hits: 10,
      page: 2,
    );

    expect(response.items, hasLength(1));
    expect(response.count, 1);
    expect(response.hits, 1);
    expect(response.page, 2);
    expect(response.pageCount, 3);
    expect(response.searchMode, 'partial');
    expect(response.items.first.isbn, '1234567890');
  });

  test('throws when response body is null', () async {
    final dio = _StubDio((path, data, options) async {
      return Response(
        data: null,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    });

    final client = RakutenBooksApiClient(dio, config);

    expect(
      () => client.search(query: 'empty', searchType: RakutenSearchType.isbn),
      throwsA(isA<RakutenBooksApiException>().having(
        (e) => e.message,
        'message',
        contains('Empty response body'),
      )),
    );
  });

  test('maps timeout errors to user friendly exceptions', () async {
    final dio = _StubDio((path, data, options) async {
      throw DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: path),
      );
    });

    final client = RakutenBooksApiClient(dio, config);

    expect(
      () => client.search(query: 'slow', searchType: RakutenSearchType.keywords),
      throwsA(isA<RakutenBooksApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        408,
      )),
    );
  });

  test('maps bad responses to exceptions with details', () async {
    final dio = _StubDio((path, data, options) async {
      throw DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 502,
          data: {'error': 'upstream'},
          requestOptions: RequestOptions(path: path),
        ),
        requestOptions: RequestOptions(path: path),
      );
    });

    final client = RakutenBooksApiClient(dio, config);

    expect(
      () => client.search(query: 'bad', searchType: RakutenSearchType.keywords),
      throwsA(isA<RakutenBooksApiException>()
          .having((e) => e.statusCode, 'statusCode', 502)
          .having((e) => e.error, 'error', {'error': 'upstream'})),
    );
  });
}
