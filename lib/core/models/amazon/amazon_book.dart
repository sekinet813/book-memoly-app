import '../../shared/config/supabase_config.dart';
import '../../shared/constants/app_constants.dart';
import '../book.dart';

enum AmazonSearchType { keywords, isbn }

class AmazonBookImages {
  const AmazonBookImages({
    this.small,
    this.medium,
    this.large,
  });

  factory AmazonBookImages.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AmazonBookImages();
    }

    return AmazonBookImages(
      small: json['small'] as String?,
      medium: json['medium'] as String?,
      large: json['large'] as String?,
    );
  }

  final String? small;
  final String? medium;
  final String? large;

  String? get bestAvailable => large ?? medium ?? small;
}

class AmazonPrice {
  const AmazonPrice({
    required this.amount,
    required this.currency,
  });

  factory AmazonPrice.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AmazonPrice(amount: 0, currency: '');
    }

    return AmazonPrice(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
    );
  }

  final double amount;
  final String currency;
}

class AmazonBook {
  const AmazonBook({
    required this.asin,
    required this.title,
    this.authors = const [],
    this.publisher,
    this.publicationDate,
    this.pageCount,
    this.imageUrls = const AmazonBookImages(),
    this.averageRating,
    this.isKindle = false,
    this.amazonUrl,
    this.salesRank,
    this.listPrice,
  });

  factory AmazonBook.fromJson(Map<String, dynamic> json) {
    final images = AmazonBookImages.fromJson(
      (json['imageUrls'] as Map<String, dynamic>?),
    );

    return AmazonBook(
      asin: json['asin'] as String? ?? '',
      title: json['title'] as String? ?? 'タイトル不明',
      authors: (json['authors'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      publisher: json['publisher'] as String?,
      publicationDate: json['publicationDate'] as String?,
      pageCount: json['pageCount'] as int?,
      imageUrls: images,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      isKindle: json['isKindle'] as bool? ?? false,
      amazonUrl: json['amazonUrl'] as String?,
      salesRank: json['salesRank'] as int?,
      listPrice: (json['listPrice'] as Map<String, dynamic>?) != null
          ? AmazonPrice.fromJson(
              json['listPrice'] as Map<String, dynamic>?,
            )
          : null,
    );
  }

  final String asin;
  final String title;
  final List<String> authors;
  final String? publisher;
  final String? publicationDate;
  final int? pageCount;
  final AmazonBookImages imageUrls;
  final double? averageRating;
  final bool isKindle;
  final String? amazonUrl;
  final int? salesRank;
  final AmazonPrice? listPrice;

  Book toBook() {
    return Book(
      id: asin,
      title: title.isEmpty ? 'タイトル不明' : title,
      authors: authors.isEmpty ? null : authors.join(', '),
      thumbnailUrl: imageUrls.bestAvailable,
      publishedDate: publicationDate,
      pageCount: pageCount,
    );
  }
}

class AmazonBooksResponse {
  const AmazonBooksResponse({
    required this.items,
    this.requestId,
    this.searchType = AmazonSearchType.keywords,
  });

  factory AmazonBooksResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AmazonBook.fromJson)
        .toList();

    final searchTypeString = json['searchType'] as String?;
    final searchType = AmazonSearchType.values.firstWhere(
      (type) => type.name == searchTypeString,
      orElse: () => AmazonSearchType.keywords,
    );

    return AmazonBooksResponse(
      items: items,
      requestId: json['requestId'] as String?,
      searchType: searchType,
    );
  }

  final List<AmazonBook> items;
  final String? requestId;
  final AmazonSearchType searchType;
}

class AmazonBooksApiException implements Exception {
  const AmazonBooksApiException(this.message, {this.statusCode, this.error});

  final String message;
  final int? statusCode;
  final Object? error;

  @override
  String toString() {
    final buffer = StringBuffer('AmazonBooksApiException: $message');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (error != null) {
      buffer.write(' - details: ${error.toString()}');
    }
    return buffer.toString();
  }
}

extension SupabaseFunctionPathX on SupabaseConfig {
  String get amazonPaapiUrl => '$supabaseUrl${AppConstants.amazonPaapiFunctionPath}';
}
