import 'package:freezed_annotation/freezed_annotation.dart';

import '../book.dart';

part 'google_books_volume.freezed.dart';
part 'google_books_volume.g.dart';

@freezed
class GoogleBooksVolumesResponse with _$GoogleBooksVolumesResponse {
  const factory GoogleBooksVolumesResponse({
    @JsonKey(defaultValue: 0) @Default(0) int totalItems,
    @JsonKey(defaultValue: <GoogleBooksVolume>[])
    @Default(<GoogleBooksVolume>[])
    List<GoogleBooksVolume> items,
  }) = _GoogleBooksVolumesResponse;

  factory GoogleBooksVolumesResponse.fromJson(Map<String, dynamic> json) =>
      _$GoogleBooksVolumesResponseFromJson(json);
}

@freezed
class GoogleBooksVolume with _$GoogleBooksVolume {
  const factory GoogleBooksVolume({
    String? id,
    GoogleBooksVolumeInfo? volumeInfo,
  }) = _GoogleBooksVolume;

  factory GoogleBooksVolume.fromJson(Map<String, dynamic> json) =>
      _$GoogleBooksVolumeFromJson(json);
}

@freezed
class GoogleBooksVolumeInfo with _$GoogleBooksVolumeInfo {
  const factory GoogleBooksVolumeInfo({
    String? title,
    String? subtitle,
    List<String>? authors,
    String? publisher,
    String? publishedDate,
    String? description,
    int? pageCount,
    GoogleBooksImageLinks? imageLinks,
    List<GoogleBooksIndustryIdentifier>? industryIdentifiers,
  }) = _GoogleBooksVolumeInfo;

  factory GoogleBooksVolumeInfo.fromJson(Map<String, dynamic> json) =>
      _$GoogleBooksVolumeInfoFromJson(json);
}

@freezed
class GoogleBooksIndustryIdentifier with _$GoogleBooksIndustryIdentifier {
  const factory GoogleBooksIndustryIdentifier({
    String? type,
    String? identifier,
  }) = _GoogleBooksIndustryIdentifier;

  factory GoogleBooksIndustryIdentifier.fromJson(Map<String, dynamic> json) =>
      _$GoogleBooksIndustryIdentifierFromJson(json);
}

@freezed
class GoogleBooksImageLinks with _$GoogleBooksImageLinks {
  const factory GoogleBooksImageLinks({
    String? smallThumbnail,
    String? thumbnail,
  }) = _GoogleBooksImageLinks;

  factory GoogleBooksImageLinks.fromJson(Map<String, dynamic> json) =>
      _$GoogleBooksImageLinksFromJson(json);
}

extension GoogleBooksVolumeX on GoogleBooksVolume {
  Book toBook() {
    final info = volumeInfo;
    final identifiers = info?.industryIdentifiers ?? [];
    final identifier =
        identifiers.isNotEmpty ? identifiers.first.identifier : null;

    return Book(
      id: id ?? identifier ?? '',
      title: info?.title ?? 'タイトル不明',
      authors: info?.authors?.join(', '),
      description: info?.description,
      thumbnailUrl: info?.imageLinks?.thumbnail
          ?.replaceFirst('http://', 'https://'),
      publishedDate: info?.publishedDate,
      pageCount: info?.pageCount,
    );
  }
}
