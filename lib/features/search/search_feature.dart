import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/models/book.dart';
import '../../shared/constants/app_constants.dart';

final _dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(baseUrl: AppConstants.googleBooksApiBaseUrl),
  );
});

final bookSearchRepositoryProvider = Provider<BookSearchRepository>((ref) {
  return BookSearchRepository(ref.read(_dioProvider));
});

class BookSearchRepository {
  BookSearchRepository(this._dio);

  final Dio _dio;

  Future<List<Book>> searchBooks({String? title, String? isbn}) async {
    final cleanedTitle = title?.trim() ?? '';
    final cleanedIsbn = isbn?.trim() ?? '';

    if (cleanedTitle.isEmpty && cleanedIsbn.isEmpty) {
      return const [];
    }

    final queryParts = <String>[];

    if (cleanedTitle.isNotEmpty) {
      queryParts.add(cleanedTitle);
    }

    if (cleanedIsbn.isNotEmpty) {
      queryParts.add('isbn:$cleanedIsbn');
    }

    final response = await _dio.get<Map<String, dynamic>>("/volumes", queryParameters: {
      'q': queryParts.join('+'),
      'maxResults': 20,
    });

    final items = response.data?['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return const [];
    }

    return items.map<Book>((dynamic rawItem) {
      final item = rawItem as Map<String, dynamic>;
      final volumeInfo = item['volumeInfo'] as Map<String, dynamic>? ?? {};
      final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
      final authors = volumeInfo['authors'] as List<dynamic>?;

      return Book(
        id: item['id'] as String? ?? volumeInfo['industryIdentifiers']?.first?['identifier'] as String? ?? '',
        title: volumeInfo['title'] as String? ?? 'タイトル不明',
        authors: authors?.join(', '),
        description: volumeInfo['description'] as String?,
        thumbnailUrl: (imageLinks?['thumbnail'] as String?)
            ?.replaceFirst('http://', 'https://'),
        publishedDate: volumeInfo['publishedDate'] as String?,
        pageCount: (volumeInfo['pageCount'] as num?)?.toInt(),
      );
    }).toList();
  }
}

class SearchState {
  const SearchState({
    required this.results,
    this.hasSearched = false,
  });

  final AsyncValue<List<Book>> results;
  final bool hasSearched;

  SearchState copyWith({
    AsyncValue<List<Book>>? results,
    bool? hasSearched,
  }) {
    return SearchState(
      results: results ?? this.results,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

final searchNotifierProvider =
    StateNotifierProvider<BookSearchNotifier, SearchState>((ref) {
  final repository = ref.read(bookSearchRepositoryProvider);
  return BookSearchNotifier(repository);
});

class BookSearchNotifier extends StateNotifier<SearchState> {
  BookSearchNotifier(this._repository)
      : super(const SearchState(results: AsyncValue.data([])));

  final BookSearchRepository _repository;

  Future<void> search({String? title, String? isbn}) async {
    state = state.copyWith(results: const AsyncValue.loading(), hasSearched: true);

    try {
      final books = await _repository.searchBooks(title: title, isbn: isbn);
      state = state.copyWith(results: AsyncValue.data(books));
    } catch (error, stackTrace) {
      state = state.copyWith(results: AsyncValue.error(error, stackTrace));
    }
  }
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _isbnController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _isbnController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('書籍検索'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'タイトル',
                      hintText: '例: Effective Dart',
                      prefixIcon: Icon(Icons.title),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _triggerSearch(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _isbnController,
                    decoration: const InputDecoration(
                      labelText: 'ISBN',
                      hintText: '例: 978-0134685991',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _triggerSearch(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _triggerSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('検索する'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: searchState.results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorView(error: error),
                data: (books) => _SearchResults(
                  books: books,
                  hasSearched: searchState.hasSearched,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSearch() {
    ref.read(searchNotifierProvider.notifier).search(
          title: _titleController.text,
          isbn: _isbnController.text,
        );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.books,
    required this.hasSearched,
  });

  final List<Book> books;
  final bool hasSearched;

  @override
  Widget build(BuildContext context) {
    if (!hasSearched) {
      return const Center(
        child: Text('タイトルまたはISBNを入力して検索してください'),
      );
    }

    if (books.isEmpty) {
      return const Center(
        child: Text('検索結果が見つかりませんでした'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookListTile(book: book);
      },
    );
  }
}

class _BookListTile extends StatelessWidget {
  const _BookListTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _BookThumbnail(url: book.thumbnailUrl),
        title: Text(book.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.authors?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(book.authors!),
              ),
            if (book.publishedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('出版日: ${book.publishedDate}'),
              ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookDetailPage(book: book),
            ),
          );
        },
      ),
    );
  }
}

class _BookThumbnail extends StatelessWidget {
  const _BookThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = SizedBox(
      width: 60,
      height: 90,
      child: ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Icon(Icons.menu_book),
      ),
    );

    if (url == null) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: 60,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const SizedBox(
            width: 60,
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('検索中にエラーが発生しました'),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({required this.book, super.key});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('書籍詳細'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: _BookThumbnail(url: book.thumbnailUrl),
              ),
              const SizedBox(height: 16),
              Text(
                book.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (book.authors?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('著者: ${book.authors}'),
              ],
              if (book.publishedDate != null) ...[
                const SizedBox(height: 8),
                Text('出版日: ${book.publishedDate}'),
              ],
              if (book.pageCount != null) ...[
                const SizedBox(height: 8),
                Text('ページ数: ${book.pageCount}'),
              ],
              const SizedBox(height: 16),
              const Text(
                '概要',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                book.description ?? '説明がありません',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
