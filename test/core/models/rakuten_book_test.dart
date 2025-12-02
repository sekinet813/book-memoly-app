import 'package:book_memoly_app/core/models/rakuten/rakuten_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toBook handles missing and empty fields gracefully', () {
    const rakutenBook = RakutenBook(
      title: '',
      author: '',
      publisherName: ' ',
      salesDate: '',
      isbn: '',
      itemCaption: '  ',
      images: RakutenBookImages(medium: 'https://example.com/medium.png'),
      itemUrl: 'https://rakuten.jp/items/1',
    );

    final book = rakutenBook.toBook();

    expect(book.id, 'https://rakuten.jp/items/1');
    expect(book.title, 'タイトル不明');
    expect(book.authors, isNull);
    expect(book.description, isNull);
    expect(book.publisher, isNull);
    expect(book.publishedDate, isNull);
    expect(book.isbn, isNull);
    expect(book.rakutenUrl, 'https://rakuten.jp/items/1');
    expect(book.thumbnailUrl, 'https://example.com/medium.png');
  });

  test('toBook splits authors by multiple delimiters and trims whitespace', () {
    const rakutenBook = RakutenBook(
      title: 'Dart Guide',
      author: 'Alice／ Bob,Charlie /Dave',
      publisherName: 'Tech Press',
      salesDate: '2024',
      isbn: '9876543210',
      itemCaption: 'Learn Dart effectively.',
      images: RakutenBookImages(small: 'https://example.com/small.png'),
      itemUrl: 'https://rakuten.jp/items/2',
    );

    final book = rakutenBook.toBook();

    expect(book.id, '9876543210');
    expect(book.authors, 'Alice, Bob, Charlie, Dave');
    expect(book.title, 'Dart Guide');
    expect(book.description, 'Learn Dart effectively.');
    expect(book.publishedDate, '2024');
    expect(book.publisher, 'Tech Press');
    expect(book.thumbnailUrl, 'https://example.com/small.png');
  });
}
