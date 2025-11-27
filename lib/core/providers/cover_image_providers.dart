import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/database_providers.dart';
import '../services/cover_image_service.dart';

final coverImageServiceProvider = Provider<CoverImageService>((ref) {
  return CoverImageService();
});

final coverImageProvider = FutureProvider.family<String?, String>((ref, bookId) async {
  final service = ref.read(coverImageServiceProvider);
  final url = await service.fetchCoverImage(bookId);

  return url;
});

final cachedCoverImageProvider = FutureProvider.family<String?, (String id, bool cache)>(
  (ref, params) async {
    final bookId = params.$1;
    final shouldCache = params.$2;

    final currentThumbnail = ref
        .read(localDatabaseRepositoryProvider)
        .findBookByGoogleId(bookId)
        .then((book) => book?.thumbnailUrl);

    final existing = await currentThumbnail;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final url = await ref.watch(coverImageProvider(bookId).future);

    if (url != null && shouldCache) {
      await ref.read(localDatabaseRepositoryProvider).updateBookThumbnail(bookId, url);
    }

    return url;
  },
);
