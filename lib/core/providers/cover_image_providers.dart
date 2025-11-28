import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/database_providers.dart';
import '../services/cover_image_service.dart';

final coverImageServiceProvider = Provider<CoverImageService>((ref) {
  return CoverImageService();
});

final coverImageProvider = FutureProvider.family<String?, String?>(
  (ref, isbn) async {
    debugPrint('[coverImageProvider] Fetching cover image for ISBN: $isbn');
    final service = ref.read(coverImageServiceProvider);
    final url = await service.fetchCoverImage(isbn);
    debugPrint('[coverImageProvider] Cover image URL result: $url');
    return url;
  },
);

final cachedCoverImageProvider =
    FutureProvider.family<String?, (String id, String? isbn, bool cache)>(
  (ref, params) async {
    final bookId = params.$1;
    final isbn = params.$2;
    final shouldCache = params.$3;

    debugPrint('[cachedCoverImageProvider] Called with bookId: $bookId, isbn: $isbn, cache: $shouldCache');

    final currentThumbnail = ref
        .read(localDatabaseRepositoryProvider)
        .findBookByGoogleId(bookId)
        .then((book) => book?.thumbnailUrl);

    final existing = await currentThumbnail;
    if (existing != null && existing.isNotEmpty) {
      debugPrint('[cachedCoverImageProvider] Found existing thumbnail in database: $existing');
      return existing;
    }

    // ISBNがnullまたは空の場合は、bookIdからISBNを抽出を試みる
    final isbnToUse = isbn ?? CoverImageService.extractIsbn(bookId);
    debugPrint('[cachedCoverImageProvider] ISBN to use: $isbnToUse');
    
    // ISBNが取得できない場合はnullを返す
    if (isbnToUse == null || isbnToUse.isEmpty) {
      debugPrint('[cachedCoverImageProvider] No ISBN available, returning null');
      return null;
    }

    debugPrint('[cachedCoverImageProvider] Fetching cover image for ISBN: $isbnToUse');
    final url = await ref.watch(coverImageProvider(isbnToUse).future);
    debugPrint('[cachedCoverImageProvider] Cover image URL result: $url');

    if (url != null && shouldCache) {
      debugPrint('[cachedCoverImageProvider] Caching cover image URL: $url');
      await ref.read(localDatabaseRepositoryProvider).updateBookThumbnail(bookId, url);
    }

    return url;
  },
);
