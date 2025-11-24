import '../book.dart';

enum RakutenSearchType { keywords, isbn }

class RakutenBookImages {
  const RakutenBookImages({
    this.small,
    this.medium,
    this.large,
  });

  factory RakutenBookImages.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RakutenBookImages();
    }

    return RakutenBookImages(
      small: json['smallImageUrl'] as String?,
      medium: json['mediumImageUrl'] as String?,
      large: json['largeImageUrl'] as String?,
    );
  }

  final String? small;
  final String? medium;
  final String? large;

  String? get bestAvailable => large ?? medium ?? small;
}

class RakutenBook {
  const RakutenBook({
    required this.title,
    this.author,
    this.publisherName,
    this.salesDate,
    this.isbn,
    this.itemCaption,
    this.images = const RakutenBookImages(),
    this.itemUrl,
  });

  factory RakutenBook.fromJson(Map<String, dynamic> json) {
    final images = RakutenBookImages.fromJson(json);

    return RakutenBook(
      title: json['title'] as String? ?? 'タイトル不明',
      author: json['author'] as String?,
      publisherName: json['publisherName'] as String?,
      salesDate: json['salesDate'] as String?,
      isbn: json['isbn'] as String?,
      itemCaption: json['itemCaption'] as String?,
      images: images,
      itemUrl: json['itemUrl'] as String?,
    );
  }

  final String title;
  final String? author;
  final String? publisherName;
  final String? salesDate;
  final String? isbn;
  final String? itemCaption;
  final RakutenBookImages images;
  final String? itemUrl;

  Book toBook() {
    final authorNames = author?.split(RegExp(r'[／/,]')).map((a) => a.trim()).where(
          (name) => name.isNotEmpty,
        )
        .toList();

    final description =
        (itemCaption != null && itemCaption!.trim().isNotEmpty) ? itemCaption : null;
    final publisher =
        (publisherName != null && publisherName!.trim().isNotEmpty) ? publisherName : null;
    final publishedDate =
        (salesDate != null && salesDate!.trim().isNotEmpty) ? salesDate : null;
    final isbnCode = (isbn != null && isbn!.trim().isNotEmpty) ? isbn : null;

    final bookId = isbnCode ?? itemUrl ?? title;

    return Book(
      id: bookId,
      title: title.isEmpty ? 'タイトル不明' : title,
      authors: (authorNames == null || authorNames.isEmpty)
          ? null
          : authorNames.join(', '),
      description: description,
      thumbnailUrl: images.bestAvailable,
      publishedDate: publishedDate,
      publisher: publisher,
      isbn: isbnCode,
      rakutenUrl: itemUrl,
    );
  }
}

class RakutenBooksResponse {
  const RakutenBooksResponse({
    required this.items,
    this.count,
    this.hits,
    this.page,
  });

  factory RakutenBooksResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['Items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) =>
            item['Item'] is Map<String, dynamic> ? item['Item'] as Map<String, dynamic> : item)
        .map(RakutenBook.fromJson)
        .toList();

    return RakutenBooksResponse(
      items: items,
      count: json['count'] as int?,
      hits: json['hits'] as int?,
      page: json['page'] as int?,
    );
  }

  final List<RakutenBook> items;
  final int? count;
  final int? hits;
  final int? page;
}

class RakutenBooksApiException implements Exception {
  const RakutenBooksApiException(this.message, {this.statusCode, this.error});

  final String message;
  final int? statusCode;
  final Object? error;

  @override
  String toString() {
    final buffer = StringBuffer('RakutenBooksApiException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (error != null) {
      buffer.write(' - details: ${error.toString()}');
    }
    return buffer.toString();
  }
}
