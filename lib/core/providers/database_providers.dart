import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/local_database_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final localDatabaseRepositoryProvider =
    Provider<LocalDatabaseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalDatabaseRepository(db);
});

final bookByGoogleIdProvider =
    StreamProvider.family<BookRow?, String>((ref, googleBooksId) {
  final repository = ref.watch(localDatabaseRepositoryProvider);
  return repository.watchBookByGoogleId(googleBooksId);
});
