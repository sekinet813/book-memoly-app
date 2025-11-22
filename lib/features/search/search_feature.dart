import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/providers/database_providers.dart';
import '../../shared/constants/app_constants.dart';

final _dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConstants.googleBooksApiBaseUrl,
      // クエリパラメータのエンコーディングを明示的に設定
      queryParameters: {},
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );
});

final bookSearchRepositoryProvider = Provider<BookSearchRepository>((ref) {
  return BookSearchRepository(ref.read(_dioProvider));
});

class BookSearchRepository {
  BookSearchRepository(this._dio);

  final Dio _dio;

  Future<List<Book>> searchBooks(String keyword) async {
    final cleanedKeyword = keyword.trim();

    if (cleanedKeyword.isEmpty) {
      return const [];
    }

    // ISBNの形式（数字とハイフンのみ）の場合は、isbn:プレフィックスを付ける
    final isIsbn = RegExp(r'^[\d\-]+$').hasMatch(cleanedKeyword);
    String query;

    if (isIsbn) {
      query = 'isbn:$cleanedKeyword';
    } else {
      // タイトルと著者の両方で検索するため、intitle:とinauthor:の両方を使用
      // OR条件で検索するため、複数のクエリを試す
      // まずは通常のキーワード検索を試し、次に著者名検索も試す
      query = cleanedKeyword;
    }

    debugPrint('Google Books API query: $query');

    try {
      // まず通常のキーワード検索を試す
      var response =
          await _dio.get<Map<String, dynamic>>("/volumes", queryParameters: {
        'q': query,
        'maxResults': 20,
      });

      final totalItems = response.data?['totalItems'] as int? ?? 0;
      debugPrint('Google Books API response: $totalItems items found');

      // 結果が少ない場合、著者名検索も試す
      if (totalItems < 5 && !isIsbn) {
        final authorQuery = 'inauthor:"$cleanedKeyword"';
        debugPrint('Trying author search: $authorQuery');

        try {
          final authorResponse = await _dio
              .get<Map<String, dynamic>>("/volumes", queryParameters: {
            'q': authorQuery,
            'maxResults': 20,
          });

          final authorTotalItems =
              authorResponse.data?['totalItems'] as int? ?? 0;
          debugPrint('Author search response: $authorTotalItems items found');

          // 著者名検索の結果の方が多い場合は、そちらを使用
          if (authorTotalItems > totalItems) {
            response = authorResponse;
          }
        } catch (e) {
          debugPrint('Author search failed: $e');
          // 著者名検索が失敗しても、通常の検索結果を返す
        }
      }

      final items = response.data?['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        debugPrint('No items found in response');
        return const [];
      }

      debugPrint('Found ${items.length} books');

      final books = <Book>[];
      for (var i = 0; i < items.length; i++) {
        try {
          final rawItem = items[i] as Map<String, dynamic>;
          final item = rawItem;
          final volumeInfo = item['volumeInfo'] as Map<String, dynamic>? ?? {};
          final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
          final authors = volumeInfo['authors'] as List<dynamic>?;

          final industryIdentifiers =
              volumeInfo['industryIdentifiers'] as List<dynamic>?;
          String? identifier;
          if (industryIdentifiers?.isNotEmpty == true) {
            final firstIdentifier =
                industryIdentifiers!.first as Map<String, dynamic>?;
            identifier = firstIdentifier?['identifier'] as String?;
          }

          final book = Book(
            id: item['id'] as String? ?? identifier ?? '',
            title: volumeInfo['title'] as String? ?? 'タイトル不明',
            authors: authors?.join(', '),
            description: volumeInfo['description'] as String?,
            thumbnailUrl: (imageLinks?['thumbnail'] as String?)
                ?.replaceFirst('http://', 'https://'),
            publishedDate: volumeInfo['publishedDate'] as String?,
            pageCount: (volumeInfo['pageCount'] as num?)?.toInt(),
          );

          books.add(book);
          if (i < 3) {
            debugPrint(
                'Book ${i + 1}: ${book.title} by ${book.authors ?? "Unknown"}');
          }
        } catch (e, stackTrace) {
          debugPrint('Error parsing book at index $i: $e');
          debugPrint('Stack trace: $stackTrace');
        }
      }

      debugPrint('Successfully parsed ${books.length} books');
      return books;
    } catch (e, stackTrace) {
      debugPrint('Error searching books: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
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

  Future<void> search(String keyword) async {
    state =
        state.copyWith(results: const AsyncValue.loading(), hasSearched: true);

    try {
      final books = await _repository.searchBooks(keyword);
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
  late final TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController();
  }

  @override
  void dispose() {
    _keywordController.dispose();
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
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      labelText: 'キーワード',
                      hintText: 'タイトルや著者名を入力（例: Effective Dart、村上春樹）',
                      prefixIcon: Icon(Icons.search),
                    ),
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
    ref.read(searchNotifierProvider.notifier).search(_keywordController.text);
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
        child: Text('キーワードを入力して検索してください'),
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

class BookDetailPage extends ConsumerStatefulWidget {
  const BookDetailPage({required this.book, super.key});

  final Book book;

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  late BookStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.book.status;

    ref.listen<AsyncValue<BookRow?>>(
      bookByGoogleIdProvider(widget.book.id),
      (_, next) {
        next.whenData((bookRow) {
          if (bookRow == null) {
            return;
          }

          final status = bookStatusFromDbValue(bookRow.status);
          if (status != _selectedStatus) {
            setState(() {
              _selectedStatus = status;
            });
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookRowAsync = ref.watch(bookByGoogleIdProvider(widget.book.id));
    final existingBook = bookRowAsync.valueOrNull;

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
                child: _BookThumbnail(url: widget.book.thumbnailUrl),
              ),
              const SizedBox(height: 16),
              Text(
                widget.book.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.book.authors?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('著者: ${widget.book.authors}'),
              ],
              if (widget.book.publishedDate != null) ...[
                const SizedBox(height: 8),
                Text('出版日: ${widget.book.publishedDate}'),
              ],
              if (widget.book.pageCount != null) ...[
                const SizedBox(height: 8),
                Text('ページ数: ${widget.book.pageCount}'),
              ],
              const SizedBox(height: 16),
              const Text(
                '概要',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.book.description ?? '説明がありません',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _BookRegistrationCard(
                selectedStatus: _selectedStatus,
                onStatusChanged: (status) => setState(() {
                  _selectedStatus = status;
                }),
                onSave: () => _handleSave(existingBook),
                isRegistered: existingBook != null,
                isLoading: bookRowAsync.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(BookRow? existingBook) async {
    final repository = ref.read(localDatabaseRepositoryProvider);

    try {
      if (existingBook == null) {
        final inserted = await repository.saveBook(
          widget.book,
          status: _selectedStatus,
        );

        if (!mounted) return;
        if (inserted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('本を登録しました')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('この本は既に登録されています')),
          );
        }
      } else {
        await repository.updateBookStatus(widget.book.id, _selectedStatus);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ステータスを更新しました')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    }
  }
}

class _BookRegistrationCard extends StatelessWidget {
  const _BookRegistrationCard({
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onSave,
    required this.isRegistered,
    required this.isLoading,
  });

  final BookStatus selectedStatus;
  final ValueChanged<BookStatus> onStatusChanged;
  final VoidCallback onSave;
  final bool isRegistered;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '読書ステータス',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (isRegistered)
                  Chip(
                    label: Text('登録済み'),
                    avatar: const Icon(Icons.check, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BookStatus>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'ステータスを選択',
                border: OutlineInputBorder(),
              ),
              items: BookStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (status) {
                if (status != null) {
                  onStatusChanged(status);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onSave,
                icon: Icon(isRegistered ? Icons.save : Icons.library_add),
                label: Text(isRegistered ? 'ステータスを更新' : '本を登録'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
