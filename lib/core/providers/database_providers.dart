import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../database/app_database.dart';
import '../providers/auth_providers.dart';
import '../repositories/local_database_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final localDatabaseRepositoryProvider =
    Provider<LocalDatabaseRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    throw StateError('User must be logged in to access the database');
  }
  final db = ref.watch(appDatabaseProvider);
  return LocalDatabaseRepository(db, userId: userId);
});

final bookByGoogleIdProvider =
    StreamProvider.family<BookRow?, String>((ref, googleBooksId) {
  final repository = ref.watch(localDatabaseRepositoryProvider);
  return repository.watchBookByGoogleId(googleBooksId);
});

final notesByBookIdProvider =
    StreamProvider.family<List<NoteRow>, int>((ref, bookId) {
  final repository = ref.watch(localDatabaseRepositoryProvider);
  return repository.watchAllNotes().map((notes) {
    final filtered =
        notes.where((note) => note.bookId == bookId).toList(growable: false);
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  });
});

final noteTagsByNoteIdsProvider =
    FutureProvider.family<Map<int, List<TagRow>>, List<int>>(
  (ref, noteIds) {
    final repository = ref.watch(localDatabaseRepositoryProvider);
    if (noteIds.isEmpty) {
      return Future.value({});
    }

    final uniqueNoteIds = noteIds.toSet().toList();
    return repository.getTagsForNotes(uniqueNoteIds);
  },
);
