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
