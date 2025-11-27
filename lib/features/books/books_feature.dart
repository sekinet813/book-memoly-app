import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/providers/cover_image_providers.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../shared/constants/app_icons.dart';
import '../home/home_feature.dart';
import '../search/search_feature.dart';

class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfState = ref.watch(bookshelfNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AppPage(
      title: '本棚',
      currentDestination: AppDestination.home,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                AppIcons.books,
                color: colorScheme.primary,
                size: 26,
              ),
              Text(
                '未読/読書中/読了をカンバンで管理',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Chip(
                label: const Text('ドラッグ&ドロップで移動'),
                avatar: Icon(
                  AppIcons.touchApp,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '本のカードを長押ししてステータス列にドラッグすると状態を移動できます。カードをタップすると書籍詳細が開き、メモやアクション、状態変更が行えます。',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          bookshelfState.books.when(
            loading: () => const LoadingIndicator(),
            error: (error, _) => _ErrorText(error: error),
            data: (books) {
              if (books.isEmpty) {
                return const Text('まだ本が登録されていません。検索から追加してみましょう。');
              }

              return _BookshelfBoard(books: books);
            },
          ),
        ],
      ),
    );
  }
}

class _BookshelfBoard extends ConsumerWidget {
  const _BookshelfBoard({required this.books});

  final List<BookRow> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = BookStatus.values;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final columnWidth = isNarrow ? double.infinity : constraints.maxWidth / 3;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final status in columns)
              SizedBox(
                width: columnWidth,
                child: _ShelfColumn(
                  status: status,
                  books: books
                      .where((book) => bookStatusFromDbValue(book.status) == status)
                      .toList(),
                  color: _statusColor(status, colorScheme),
                  onMove: (book) async {
                    await ref
                        .read(bookshelfNotifierProvider.notifier)
                        .moveBookToStatus(book, status);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShelfColumn extends StatelessWidget {
  const _ShelfColumn({
    required this.status,
    required this.books,
    required this.color,
    required this.onMove,
  });

  final BookStatus status;
  final List<BookRow> books;
  final Color color;
  final Future<void> Function(BookRow book) onMove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DragTarget<BookRow>(
      onWillAccept: (data) => data != null && bookStatusFromDbValue(data.status) != status,
      onAccept: (book) => onMove(book),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.08)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? color : colorScheme.outlineVariant,
              width: isActive ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(AppIcons.circle, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${books.length}冊',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.swapVert, color: colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              if (books.isEmpty)
                Text(
                  'ここに本をドラッグ',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ...books.map(
                (book) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ShelfBookCard(
                    book: book,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShelfBookCard extends StatelessWidget {
  const _ShelfBookCard({required this.book, required this.color});

  final BookRow book;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final status = bookStatusFromDbValue(book.status);
    final theme = Theme.of(context);

    return LongPressDraggable<BookRow>(
      data: book,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: _BookCardBody(
            book: book,
            color: color,
            status: status,
            theme: theme,
            isDragging: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _BookCardBody(
          book: book,
          color: color,
          status: status,
          theme: theme,
          isDragging: false,
        ),
      ),
      child: _BookCardBody(
        book: book,
        color: color,
        status: status,
        theme: theme,
        isDragging: false,
      ),
    );
  }
}

class _BookCardBody extends StatelessWidget {
  const _BookCardBody({
    required this.book,
    required this.color,
    required this.status,
    required this.theme,
    required this.isDragging,
  });

  final BookRow book;
  final Color color;
  final BookStatus status;
  final ThemeData theme;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final bookModel = Book(
          id: book.googleBooksId,
          title: book.title,
          authors: book.authors,
          description: book.description,
          thumbnailUrl: book.thumbnailUrl,
          publishedDate: book.publishedDate,
          pageCount: book.pageCount,
          status: status,
          createdAt: book.createdAt,
          updatedAt: book.updatedAt,
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookDetailPage(book: bookModel),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isDragging
                ? color
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            _ShelfBookCover(
              bookId: book.googleBooksId,
              thumbnailUrl: book.thumbnailUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (book.authors != null && book.authors!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.authors!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatusPill(status: status, color: color),
                      const SizedBox(width: 8),
                      if (book.pageCount != null)
                        Text(
                          '${book.pageCount}p',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              AppIcons.chevronRight,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfBookCover extends ConsumerWidget {
  const _ShelfBookCover({
    required this.bookId,
    this.isbn,
    required this.thumbnailUrl,
  });

  final String bookId;
  final String? isbn;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverAsync = (thumbnailUrl == null || thumbnailUrl!.isEmpty)
        ? ref.watch(cachedCoverImageProvider((bookId, isbn, true)))
        : const AsyncValue<String?>.data(null);

    final resolvedUrl =
        (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
            ? thumbnailUrl
            : coverAsync.valueOrNull;

    if (resolvedUrl == null) {
      return Container(
        width: 70,
        height: 96,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          AppIcons.menuBook,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        resolvedUrl,
        width: 70,
        height: 96,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final BookStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.bookmark, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Text(
      'データの取得中にエラーが発生しました: $error',
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.error),
    );
  }
}

Color _statusColor(BookStatus status, ColorScheme colorScheme) {
  switch (status) {
    case BookStatus.unread:
      return colorScheme.secondary;
    case BookStatus.reading:
      return colorScheme.primary;
    case BookStatus.finished:
      return colorScheme.tertiary;
  }
}
