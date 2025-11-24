import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/tag_selector.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/models/rakuten/rakuten_book.dart';
import '../../core/services/rakuten_book_api_client.dart';
import '../../shared/constants/app_icons.dart';

final bookSearchRepositoryProvider = Provider<BookSearchRepository>((ref) {
  return BookSearchRepository(ref.read(rakutenBooksApiClientProvider));
});

class BookSearchRepository {
  BookSearchRepository(this._client);

  final RakutenBooksApiClient _client;

  Future<List<Book>> searchBooks(String keyword) async {
    final cleanedKeyword = keyword.trim();

    if (cleanedKeyword.isEmpty) {
      return const [];
    }

    final isIsbn = RegExp(r'^[\d\-]+$').hasMatch(cleanedKeyword);
    final queryType =
        isIsbn ? RakutenSearchType.isbn : RakutenSearchType.keywords;

    debugPrint('Rakuten Books API query ($queryType): $cleanedKeyword');

    try {
      final response = await _client.search(
        query: cleanedKeyword,
        searchType: queryType,
      );

      if (response.items.isEmpty) {
        debugPrint('No items found in response');
        return const [];
      }

      debugPrint('Found ${response.items.length} books via Rakuten Books API');

      final books = response.items
          .map((item) => item.toBook())
          .where((book) => book.id.isNotEmpty)
          .toList();

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

class LocalSearchState {
  const LocalSearchState({
    required this.results,
    this.hasSearched = false,
    this.keyword = '',
    this.statusFilter,
    this.selectedTagIds = const {},
  });

  static const _statusFilterSentinel = Object();

  final AsyncValue<List<LocalSearchResult>> results;
  final bool hasSearched;
  final String keyword;
  final BookStatus? statusFilter;
  final Set<int> selectedTagIds;

  LocalSearchState copyWith({
    AsyncValue<List<LocalSearchResult>>? results,
    bool? hasSearched,
    String? keyword,
    Object? statusFilter = _statusFilterSentinel,
    Set<int>? selectedTagIds,
  }) {
    return LocalSearchState(
      results: results ?? this.results,
      hasSearched: hasSearched ?? this.hasSearched,
      keyword: keyword ?? this.keyword,
      statusFilter: statusFilter == _statusFilterSentinel
          ? this.statusFilter
          : statusFilter as BookStatus?,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
    );
  }
}

final localSearchNotifierProvider =
    StateNotifierProvider<LocalSearchNotifier, LocalSearchState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return LocalSearchNotifier(repository);
});

class LocalSearchNotifier extends StateNotifier<LocalSearchState> {
  LocalSearchNotifier(this._repository)
      : super(const LocalSearchState(results: AsyncValue.data([])));

  final LocalDatabaseRepository _repository;

  Future<void> search(String keyword) async {
    final cleanedKeyword = keyword.trim();

    state = state.copyWith(
      results: const AsyncValue.loading(),
      hasSearched: true,
      keyword: cleanedKeyword,
    );

    try {
      final results = await _repository.searchBooksAndNotes(
        cleanedKeyword,
        statusFilter: state.statusFilter,
        tagIds: state.selectedTagIds,
      );
      state = state.copyWith(results: AsyncValue.data(results));
    } catch (error, stackTrace) {
      state = state.copyWith(results: AsyncValue.error(error, stackTrace));
    }
  }

  void setStatusFilter(BookStatus? status) {
    state = state.copyWith(statusFilter: status);

    if (state.hasSearched && state.keyword.isNotEmpty) {
      unawaited(search(state.keyword));
    }
  }

  void setTagFilters(Set<int> tagIds) {
    state = state.copyWith(selectedTagIds: tagIds);

    if (state.hasSearched) {
      unawaited(search(state.keyword));
    }
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: AppPage(
        title: '検索',
        padding: EdgeInsets.zero,
        currentDestination: AppDestination.search,
        bottom: TabBar(
          tabs: [
            Tab(text: 'オンライン検索'),
            Tab(text: 'ローカル検索'),
          ],
        ),
        child: TabBarView(
          children: [
            _OnlineSearchTab(),
            _LocalSearchTab(),
          ],
        ),
      ),
    );
  }
}

class _OnlineSearchTab extends ConsumerStatefulWidget {
  const _OnlineSearchTab();

  @override
  ConsumerState<_OnlineSearchTab> createState() => _OnlineSearchTabState();
}

class _OnlineSearchTabState extends ConsumerState<_OnlineSearchTab> {
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

    return Column(
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
                  prefixIcon: Icon(AppIcons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _triggerSearch(),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: _triggerSearch,
                icon: AppIcons.search,
                label: '検索する',
                expand: true,
              ),
            ],
          ),
        ),
        Expanded(
          child: searchState.results.when(
            loading: () => const LoadingIndicator(),
            error: (error, _) => _ErrorView(error: error),
            data: (books) => _SearchResults(
              books: books,
              hasSearched: searchState.hasSearched,
            ),
          ),
        ),
      ],
    );
  }

  void _triggerSearch() {
    ref.read(searchNotifierProvider.notifier).search(_keywordController.text);
  }
}

class _LocalSearchTab extends ConsumerStatefulWidget {
  const _LocalSearchTab();

  @override
  ConsumerState<_LocalSearchTab> createState() => _LocalSearchTabState();
}

class _LocalSearchTabState extends ConsumerState<_LocalSearchTab> {
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
    final localSearchState = ref.watch(localSearchNotifierProvider);

    return Column(
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
                  hintText: 'タイトル / 著者 / メモ内容 で検索',
                  prefixIcon: Icon(AppIcons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _triggerSearch(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(AppIcons.filter),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<BookStatus?>(
                      value: localSearchState.statusFilter,
                      isExpanded: true,
                      hint: const Text('すべてのステータス'),
                      items: [
                        const DropdownMenuItem<BookStatus?>(
                          value: null,
                          child: Text('すべて'),
                        ),
                        ...BookStatus.values.map(
                          (status) => DropdownMenuItem<BookStatus>(
                            value: status,
                            child: Text(status.label),
                          ),
                        ),
                      ],
                      onChanged: (status) {
                        ref
                            .read(localSearchNotifierProvider.notifier)
                            .setStatusFilter(status);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.label),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('タグで絞り込む'),
                        const SizedBox(height: 8),
                        TagSelector(
                          selectedTagIds: localSearchState.selectedTagIds,
                          onSelectionChanged: (ids) {
                            ref
                                .read(localSearchNotifierProvider.notifier)
                                .setTagFilters(ids);
                          },
                          showAddButton: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                onPressed: _triggerSearch,
                icon: AppIcons.manageSearch,
                label: 'ローカルを検索',
                expand: true,
              ),
            ],
          ),
        ),
        Expanded(
          child: localSearchState.results.when(
            loading: () => const LoadingIndicator(),
            error: (error, _) => _ErrorView(error: error),
            data: (results) => _LocalSearchResults(
              results: results,
              hasSearched: localSearchState.hasSearched,
            ),
          ),
        ),
      ],
    );
  }

  void _triggerSearch() {
    ref
        .read(localSearchNotifierProvider.notifier)
        .search(_keywordController.text);
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
      return const EmptyState(
        title: '検索キーワードを入力してください',
        message: 'タイトルや著者名で検索できます。',
        icon: AppIcons.search,
      );
    }

    if (books.isEmpty) {
      return const EmptyState(
        title: '検索結果が見つかりませんでした',
        message: 'キーワードを少し変えて、もう一度お試しください。',
        icon: AppIcons.manageSearch,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: books.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const SectionHeader(title: '検索結果');
        }

        final book = books[index - 1];
        return _BookListTile(book: book);
      },
    );
  }
}

class _LocalSearchResults extends StatelessWidget {
  const _LocalSearchResults({
    required this.results,
    required this.hasSearched,
  });

  final List<LocalSearchResult> results;
  final bool hasSearched;

  @override
  Widget build(BuildContext context) {
    if (!hasSearched) {
      return const EmptyState(
        title: 'キーワードやタグを選んで検索してください',
        message: '登録済みの本やメモの中から探せます。',
        icon: AppIcons.manageSearch,
      );
    }

    if (results.isEmpty) {
      return const EmptyState(
        title: '一致する結果がありませんでした',
        message: '絞り込み条件やキーワードを見直してください。',
        icon: AppIcons.filter,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return SectionHeader(
            title: 'ローカル検索結果 (${results.length})',
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }

        final result = results[index - 1];
        final status = bookStatusFromDbValue(result.book.status);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      result.book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(status.label),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (result.book.authors?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  result.book.authors!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (result.bookTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                TagChipList(tags: result.bookTags),
              ],
              const SizedBox(height: 8),
              if (result.matchingNotes.isNotEmpty) ...[
                Text(
                  '一致したメモ (${result.matchingNotes.length})',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...result.matchingNotes.take(3).map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                note.content,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                            if ((result.noteTags[note.id] ?? []).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: TagChipList(
                                    tags: result.noteTags[note.id]!),
                              ),
                          ],
                        ),
                      ),
                    ),
                if (result.matchingNotes.length > 3)
                  Text(
                    '他 ${result.matchingNotes.length - 3} 件のメモが一致',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ] else
                Text(
                  'タイトルや著者で一致しました',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BookListTile extends StatelessWidget {
  const _BookListTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookDetailPage(book: book),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BookThumbnail(url: book.thumbnailUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (book.authors?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      book.authors!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (book.publisher != null)
                      _MetaChip(
                        icon: AppIcons.label,
                        label: book.publisher!,
                      ),
                    if (book.publishedDate != null)
                      _MetaChip(
                        icon: AppIcons.calendar,
                        label: book.publishedDate!,
                      ),
                    if (book.isbn != null)
                      _MetaChip(
                        icon: AppIcons.manageSearch,
                        label: 'ISBN: ${book.isbn!}',
                      ),
                    if (book.pageCount != null)
                      _MetaChip(
                        icon: AppIcons.book,
                        label: '${book.pageCount}ページ',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(AppIcons.chevronRight),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: AppIconSizes.small),
      label: Text(label),
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
        child: Icon(AppIcons.menuBook),
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
            const Icon(
              AppIcons.error,
              size: AppIconSizes.extraLarge,
              color: Colors.redAccent,
            ),
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
  BookStatus? _selectedStatus;
  DateTime? _startedAt;
  DateTime? _finishedAt;
  bool _isInitialized = false;
  bool _isLoadingTags = false;
  int? _bookRowId;
  Set<int> _selectedTagIds = {};

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.book.status;
  }

  void _initializeFromDatabase(BookRow? bookRow) {
    if (bookRow == null || _isInitialized) {
      return;
    }

    final status = bookStatusFromDbValue(bookRow.status);
    setState(() {
      _selectedStatus = status;
      _startedAt = bookRow.startedAt;
      _finishedAt = bookRow.finishedAt;
      _isInitialized = true;
      _bookRowId = bookRow.id;
      _selectedTagIds = {};
    });

    _loadTagsForBook(bookRow);
  }

  void _updateFromDatabase(BookRow? bookRow) {
    if (bookRow == null) {
      return;
    }

    final status = bookStatusFromDbValue(bookRow.status);
    bool needsUpdate = false;

    if (status != _selectedStatus) {
      _selectedStatus = status;
      needsUpdate = true;
    }

    if (_startedAt != bookRow.startedAt || _finishedAt != bookRow.finishedAt) {
      _startedAt = bookRow.startedAt;
      _finishedAt = bookRow.finishedAt;
      needsUpdate = true;
    }

    if (_bookRowId != bookRow.id) {
      _bookRowId = bookRow.id;
      _loadTagsForBook(bookRow);
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookRowAsync = ref.watch(bookByGoogleIdProvider(widget.book.id));
    final existingBook = bookRowAsync.valueOrNull;

    // ref.listenはbuildメソッド内でのみ使用可能
    ref.listen<AsyncValue<BookRow?>>(
      bookByGoogleIdProvider(widget.book.id),
      (previous, next) {
        next.whenData((bookRow) {
          if (!_isInitialized) {
            _initializeFromDatabase(bookRow);
          } else {
            _updateFromDatabase(bookRow);
          }
        });
      },
    );

    // 初期化されていない場合は、既存のデータから初期化
    if (!_isInitialized && existingBook != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeFromDatabase(existingBook);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('書籍詳細'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BookThumbnail(url: widget.book.thumbnailUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (widget.book.authors?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.book.authors!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (widget.book.publisher != null)
                              _MetaChip(
                                icon: AppIcons.label,
                                label: widget.book.publisher!,
                              ),
                            if (widget.book.publishedDate != null)
                              _MetaChip(
                                icon: AppIcons.calendar,
                                label: widget.book.publishedDate!,
                              ),
                            if (widget.book.isbn != null)
                              _MetaChip(
                                icon: AppIcons.manageSearch,
                                label: 'ISBN: ${widget.book.isbn!}',
                              ),
                            if (widget.book.pageCount != null)
                              _MetaChip(
                                icon: AppIcons.book,
                                label: '${widget.book.pageCount}ページ',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.book.rakutenUrl != null) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'オンラインで確認',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      onPressed: _openRakutenUrl,
                      icon: AppIcons.export,
                      label: '楽天で見る',
                      expand: true,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '概要',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.book.description ?? '説明がありません',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ReadingPeriodCard(
              startedAt: _startedAt,
              finishedAt: _finishedAt,
              onTapStartDate: () => _pickDate(isStartDate: true),
              onTapEndDate: () => _pickDate(isStartDate: false),
              onClearStartDate: _startedAt != null
                  ? () {
                      setState(() {
                        _startedAt = null;
                      });
                    }
                  : null,
              onClearEndDate: _finishedAt != null
                  ? () {
                      setState(() {
                        _finishedAt = null;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            _BookTagCard(
              selectedTagIds: _selectedTagIds,
              isLoading: _isLoadingTags,
              onSelectionChanged: (tags) {
                setState(() {
                  _selectedTagIds = tags;
                });
              },
              onSave: existingBook == null
                  ? null
                  : () => _saveTags(existingBook.id),
              isRegistered: existingBook != null,
            ),
            const SizedBox(height: 12),
            _BookRegistrationCard(
              selectedStatus: _selectedStatus ?? widget.book.status,
              onStatusChanged: (status) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                setState(() {
                  _selectedStatus = status;

                  // 読書中になったら、開始日が未設定の場合は今日を設定
                  if (status == BookStatus.reading && _startedAt == null) {
                    _startedAt = today;
                  }

                  // 読了になったら、終了日が未設定の場合は今日を設定
                  if (status == BookStatus.finished && _finishedAt == null) {
                    _finishedAt = today;
                  }
                });
              },
              onSave: () => _handleSave(existingBook),
              isRegistered: existingBook != null,
              isLoading: bookRowAsync.isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTagsForBook(BookRow bookRow) async {
    setState(() {
      _isLoadingTags = true;
      _bookRowId = bookRow.id;
    });

    try {
      final repository = ref.read(localDatabaseRepositoryProvider);
      final tags = await repository.getTagsForBook(bookRow.id);
      if (!mounted) return;
      setState(() {
        _selectedTagIds = tags.map((tag) => tag.id).toSet();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  Future<void> _saveTags(int bookId) async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      final repository = ref.read(localDatabaseRepositoryProvider);
      await repository.setTagsForBook(
        bookId: bookId,
        tagIds: _selectedTagIds.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タグを更新しました')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  Future<void> _openRakutenUrl() async {
    final url = widget.book.rakutenUrl;
    if (url == null) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効なURLが見つかりませんでした')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクを開けませんでした')),
      );
    }
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? _startedAt ?? DateTime.now()
        : _finishedAt ?? _startedAt ?? DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      if (isStartDate) {
        _startedAt = selectedDate;
      } else {
        _finishedAt = selectedDate;
      }
    });
  }

  Future<void> _handleSave(BookRow? existingBook) async {
    final repository = ref.read(localDatabaseRepositoryProvider);

    // 保存時に状態に応じて日付を自動設定
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final status = _selectedStatus ?? widget.book.status;

    DateTime? startedAt = _startedAt;
    DateTime? finishedAt = _finishedAt;

    // 読書中になったら、開始日が未設定の場合は今日を設定
    if (status == BookStatus.reading && startedAt == null) {
      startedAt = today;
    }

    // 読了になったら、終了日が未設定の場合は今日を設定
    if (status == BookStatus.finished && finishedAt == null) {
      finishedAt = today;
    }

    if (startedAt != null && finishedAt != null) {
      if (finishedAt.isBefore(startedAt)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('終了日は開始日以降を選択してください')),
        );
        return;
      }
    }

    try {
      if (existingBook == null) {
        final inserted = await repository.saveBook(
          widget.book,
          status: status,
          startedAt: startedAt,
          finishedAt: finishedAt,
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
        await repository.updateBookReadingInfo(
          widget.book.id,
          status: status,
          startedAt: startedAt,
          finishedAt: finishedAt,
        );

        // UIの状態も更新
        setState(() {
          _startedAt = startedAt;
          _finishedAt = finishedAt;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('読書情報を更新しました')),
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
    return AppCard(
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
                const Chip(
                  label: Text('登録済み'),
                  avatar: Icon(AppIcons.check, size: AppIconSizes.small),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BookStatus>(
            initialValue: selectedStatus,
            decoration: const InputDecoration(
              labelText: 'ステータスを選択',
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
          PrimaryButton(
            onPressed: isLoading ? null : onSave,
            icon: isRegistered ? AppIcons.save : AppIcons.addLibrary,
            label: isRegistered ? 'ステータスを更新' : '本を登録',
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _ReadingPeriodCard extends StatelessWidget {
  const _ReadingPeriodCard({
    required this.startedAt,
    required this.finishedAt,
    required this.onTapStartDate,
    required this.onTapEndDate,
    this.onClearStartDate,
    this.onClearEndDate,
  });

  final DateTime? startedAt;
  final DateTime? finishedAt;
  final VoidCallback onTapStartDate;
  final VoidCallback onTapEndDate;
  final VoidCallback? onClearStartDate;
  final VoidCallback? onClearEndDate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '読書期間',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _DatePickerRow(
            label: '開始日',
            date: startedAt,
            onTap: onTapStartDate,
            onClear: onClearStartDate,
          ),
          const SizedBox(height: 12),
          _DatePickerRow(
            label: '終了日',
            date: finishedAt,
            onTap: onTapEndDate,
            onClear: onClearEndDate,
          ),
        ],
      ),
    );
  }
}

class _BookTagCard extends StatelessWidget {
  const _BookTagCard({
    required this.selectedTagIds,
    required this.onSelectionChanged,
    required this.onSave,
    required this.isRegistered,
    required this.isLoading,
  });

  final Set<int> selectedTagIds;
  final ValueChanged<Set<int>> onSelectionChanged;
  final VoidCallback? onSave;
  final bool isRegistered;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'タグ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isRegistered)
                const Chip(
                  label: Text('保存済み'),
                  avatar: Icon(AppIcons.check, size: AppIconSizes.small),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isRegistered) const Text('タグを設定するには本を登録してください'),
          const SizedBox(height: 4),
          if (isLoading)
            const LoadingIndicator()
          else
            Opacity(
              opacity: isRegistered ? 1 : 0.6,
              child: IgnorePointer(
                ignoring: !isRegistered,
                child: TagSelector(
                  selectedTagIds: selectedTagIds,
                  onSelectionChanged: onSelectionChanged,
                  showAddButton: true,
                ),
              ),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            onPressed: isLoading || onSave == null ? null : onSave,
            icon: AppIcons.save,
            label: 'タグを保存',
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final displayDate =
        date != null ? localizations.formatMediumDate(date!) : '未設定';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(AppIcons.calendar),
                label: Text(displayDate),
              ),
            ],
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'クリア',
            onPressed: onClear,
            icon: const Icon(AppIcons.close),
          ),
        ]
      ],
    );
  }
}
