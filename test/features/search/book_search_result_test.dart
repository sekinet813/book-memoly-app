import 'package:book_memoly_app/core/models/book.dart';
import 'package:book_memoly_app/features/search/search_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sampleBook = Book(id: '1', title: 'Sample Book');

  group('BookSearchResult.hasMore', () {
    test('prefers pageCount when available', () {
      const firstPage = BookSearchResult(
        books: [sampleBook],
        page: 1,
        hitsPerPage: 30,
        pageCount: 4,
      );
      const lastPage = BookSearchResult(
        books: [sampleBook],
        page: 4,
        hitsPerPage: 30,
        pageCount: 4,
      );

      expect(firstPage.hasMore, isTrue);
      expect(lastPage.hasMore, isFalse);
    });

    test('falls back to totalCount when pageCount is missing', () {
      const firstPage = BookSearchResult(
        books: [sampleBook],
        page: 1,
        hitsPerPage: 30,
        totalCount: 60,
      );
      const lastPage = BookSearchResult(
        books: [sampleBook],
        page: 2,
        hitsPerPage: 30,
        totalCount: 60,
      );

      expect(firstPage.hasMore, isTrue);
      expect(lastPage.hasMore, isFalse);
    });

    test('falls back to hitsPerPage comparison when count is null', () {
      const stillHasMore = BookSearchResult(
        books: [sampleBook],
        page: 1,
        hitsPerPage: 1,
      );
      const noMoreData = BookSearchResult(
        books: [sampleBook],
        page: 1,
        hitsPerPage: 30,
      );

      expect(stillHasMore.hasMore, isTrue);
      expect(noMoreData.hasMore, isFalse);
    });
  });
}

