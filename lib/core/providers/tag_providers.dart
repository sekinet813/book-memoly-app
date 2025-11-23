import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/local_database_repository.dart';
import 'database_providers.dart';

final tagsNotifierProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<TagRow>>>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return TagsNotifier(repository)..loadTags();
});

class TagsNotifier extends StateNotifier<AsyncValue<List<TagRow>>> {
  TagsNotifier(this._repository) : super(const AsyncValue.loading());

  final LocalDatabaseRepository _repository;

  Future<void> loadTags() async {
    state = const AsyncValue.loading();
    try {
      final tags = await _repository.getAllTags();
      state = AsyncValue.data(tags);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addTag(String name) async {
    if (name.trim().isEmpty) {
      return;
    }

    await _repository.createTag(name.trim());
    await loadTags();
  }

  Future<void> renameTag(int tagId, String name) async {
    if (name.trim().isEmpty) {
      return;
    }

    await _repository.updateTag(tagId: tagId, name: name.trim());
    await loadTags();
  }

  Future<void> deleteTag(int tagId) async {
    await _repository.deleteTag(tagId);
    await loadTags();
  }
}
