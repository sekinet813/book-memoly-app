import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/database_providers.dart';
import '../../core/providers/profile_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../shared/constants/app_constants.dart';
import '../../shared/constants/app_icons.dart';

final bookshelfNotifierProvider =
    StateNotifierProvider<BookshelfNotifier, BookshelfState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return BookshelfNotifier(repository)..loadShelf();
});

class BookshelfState {
  const BookshelfState({
    required this.books,
    required this.notes,
  });

  final AsyncValue<List<BookRow>> books;
  final AsyncValue<List<NoteRow>> notes;

  BookshelfState copyWith({
    AsyncValue<List<BookRow>>? books,
    AsyncValue<List<NoteRow>>? notes,
  }) {
    return BookshelfState(
      books: books ?? this.books,
      notes: notes ?? this.notes,
    );
  }
}

class BookshelfNotifier extends StateNotifier<BookshelfState> {
  BookshelfNotifier(this._repository)
      : super(
          const BookshelfState(
            books: AsyncValue.loading(),
            notes: AsyncValue.loading(),
          ),
        );

  final LocalDatabaseRepository _repository;

  Future<void> loadShelf() async {
    try {
      final books = await _repository.getAllBooks();
      final sortedBooks = [...books]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final notes = await _repository.getAllNotes();
      final sortedNotes = [...notes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        books: AsyncValue.data(sortedBooks),
        notes: AsyncValue.data(sortedNotes),
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        books: AsyncValue.error(error, stackTrace),
        notes: AsyncValue.error(error, stackTrace),
      );
    }
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_startSync);
  }

  Future<void> _startSync() async {
    final syncService = ref.read(supabaseSyncServiceProvider);
    await syncService?.syncIfConnected();
  }

  @override
  Widget build(BuildContext context) {
    final bookshelfState = ref.watch(bookshelfNotifierProvider);

    return AppPage(
      title: AppConstants.appName,
      actions: [
        IconButton(
          tooltip: '設定',
          onPressed: () {
            context.push('/settings');
          },
          icon: const Icon(AppIcons.settings),
        ),
        IconButton(
          tooltip: 'ログアウト',
          onPressed: () async {
            final authService = ref.read(authServiceProvider);
            if (authService != null) {
              await authService.signOut();
            }
          },
          icon: const Icon(AppIcons.logout),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      scrollable: true,
      currentDestination: AppDestination.home,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeaderSection(),
          const SizedBox(height: 18),
          _ContinueReadingSection(state: bookshelfState),
          const SizedBox(height: 20),
          _MagazineGrid(state: bookshelfState),
          const SizedBox(height: 24),
          _RecentNotesCarousel(state: bookshelfState),
        ],
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final profileService = ref.watch(profileServiceProvider);

    final name = profileState.profile?.name;
    final greeting = name != null && name.isNotEmpty ? 'Hi, $name' : 'ようこそ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '表紙で出会う、あなたの物語。',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (profileService != null) ...[
          const SizedBox(height: 12),
          _ProfileSummaryCard(profileState: profileState),
        ],
      ],
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profileState});

  final ProfileState profileState;

  @override
  Widget build(BuildContext context) {
    final profile = profileState.profile;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: profile?.avatarUrl != null
                ? NetworkImage(profile!.avatarUrl!)
                : null,
            child:
                profile?.avatarUrl == null ? const Icon(AppIcons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name.isNotEmpty == true
                      ? profile!.name
                      : 'プロフィールを設定しましょう',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.bio?.isNotEmpty == true
                      ? profile!.bio!
                      : '読書テーマや一言をここに記しましょう。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingSection extends StatelessWidget {
  const _ContinueReadingSection({required this.state});

  final BookshelfState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: AppIcons.books,
          title: 'Continue Reading',
          subtitle: 'いま読んでいる本を続けましょう',
        ),
        const SizedBox(height: 12),
        state.books.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => _ErrorText(error: error),
          data: (books) {
            final readingBooks = books
                .where((book) =>
                    bookStatusFromDbValue(book.status) == BookStatus.reading)
                .toList();

            if (readingBooks.isEmpty) {
              return const Text('読書中の本がここに表示されます');
            }

            return SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final book = readingBooks[index];
                  return SizedBox(
                    width: 160,
                    child: _BookTile(book: book),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemCount: readingBooks.length,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MagazineGrid extends StatelessWidget {
  const _MagazineGrid({required this.state});

  final BookshelfState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: AppIcons.books,
          title: 'My Magazine Shelf',
          subtitle: '表紙で並べる、美しい本棚',
        ),
        const SizedBox(height: 12),
        state.books.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => _ErrorText(error: error),
          data: (books) {
            if (books.isEmpty) {
              return const Text('まだ本が登録されていません。検索から追加してみましょう。');
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 600
                        ? 3
                        : 2;
                final childAspectRatio =
                    constraints.maxWidth > 600 ? 0.66 : 0.62;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _BookTile(book: book);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _RecentNotesCarousel extends StatelessWidget {
  const _RecentNotesCarousel({required this.state});

  final BookshelfState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: AppIcons.memo,
          title: 'Recent Notes',
          subtitle: '余韻を残したメモを振り返る',
        ),
        const SizedBox(height: 12),
        state.notes.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => _ErrorText(error: error),
          data: (notes) {
            if (notes.isEmpty) {
              return const Text('最近のメモがここに表示されます');
            }

            final books = state.books.valueOrNull ?? const [];
            return SizedBox(
              height: 180,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.84),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final book = books.firstWhere(
                    (b) => b.id == note.bookId,
                    orElse: () => BookRow(
                      id: -1,
                      userId: note.userId,
                      googleBooksId: 'unknown',
                      title: '不明な本',
                      authors: '',
                      description: null,
                      thumbnailUrl: null,
                      publishedDate: null,
                      pageCount: null,
                      status: 0,
                      startedAt: null,
                      finishedAt: null,
                      createdAt: note.createdAt,
                      updatedAt: note.updatedAt,
                    ),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _NoteCard(note: note, book: book),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});

  final BookRow book;

  @override
  Widget build(BuildContext context) {
    final status = bookStatusFromDbValue(book.status);
    final statusColor = _statusColor(status, Theme.of(context).colorScheme);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(child: _BookCover(thumbnailUrl: book.thumbnailUrl)),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Theme.of(context)
                            .colorScheme
                            .surfaceTint
                            .withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: Container(
                width: 10,
                color: statusColor,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _StatusBadge(status: status, color: statusColor),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.24),
                          Colors.black.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        if (book.authors != null &&
                            book.authors!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            book.authors!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.86)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl == null || thumbnailUrl!.isEmpty) {
      return Container(
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
        ),
        child: Center(
          child: Icon(
            AppIcons.menuBook,
            size: 44,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Ink.image(
      image: NetworkImage(thumbnailUrl!),
      fit: BoxFit.cover,
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.book});

  final NoteRow note;
  final BookRow book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.memo, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              note.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                AppIcons.bookmarkBorder,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'P.${note.pageNumber ?? '-'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              Text(
                _formatDate(note.updatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final BookStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status.label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
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

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
