import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/theme/tokens/radius.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../shared/constants/app_icons.dart';

final readingTimelineNotifierProvider = StateNotifierProvider.autoDispose<ReadingTimelineNotifier, ReadingTimelineState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return ReadingTimelineNotifier(repository: repository)..loadTimeline();
});

class ReadingTimelineState {
  const ReadingTimelineState({
    required this.items,
  });

  final AsyncValue<List<ReadingTimelineItem>> items;

  ReadingTimelineState copyWith({AsyncValue<List<ReadingTimelineItem>>? items}) {
    return ReadingTimelineState(
      items: items ?? this.items,
    );
  }
}

enum ReadingTimelineItemType {
  reading,
  started,
  finished,
  memo,
  action,
}

class ReadingTimelineItem {
  const ReadingTimelineItem({
    required this.type,
    required this.timestamp,
    this.book,
    this.note,
    this.action,
    this.readingLog,
  });

  final ReadingTimelineItemType type;
  final DateTime timestamp;
  final BookRow? book;
  final NoteRow? note;
  final ActionRow? action;
  final ReadingLogRow? readingLog;
}

class ReadingTimelineNotifier extends StateNotifier<ReadingTimelineState> {
  ReadingTimelineNotifier({required LocalDatabaseRepository repository})
      : _repository = repository,
        super(const ReadingTimelineState(items: AsyncValue.loading()));

  final LocalDatabaseRepository _repository;

  Future<void> loadTimeline() async {
    state = state.copyWith(items: const AsyncValue.loading());
    try {
      final results = await Future.wait([
        _repository.getAllBooks(),
        _repository.getAllReadingLogs(),
        _repository.getAllNotes(),
        _repository.getAllActions(),
      ]);

      final books = results[0] as List<BookRow>;
      final readingLogs = results[1] as List<ReadingLogRow>;
      final notes = results[2] as List<NoteRow>;
      final actions = results[3] as List<ActionRow>;

      final bookMap = {for (final book in books) book.id: book};

      final items = <ReadingTimelineItem>[];

      for (final book in books) {
        if (book.startedAt != null) {
          items.add(
            ReadingTimelineItem(
              type: ReadingTimelineItemType.started,
              timestamp: book.startedAt!,
              book: book,
            ),
          );
        }

        if (book.finishedAt != null) {
          items.add(
            ReadingTimelineItem(
              type: ReadingTimelineItemType.finished,
              timestamp: book.finishedAt!,
              book: book,
            ),
          );
        }
      }

      for (final log in readingLogs) {
        items.add(
          ReadingTimelineItem(
            type: ReadingTimelineItemType.reading,
            timestamp: log.updatedAt,
            book: bookMap[log.bookId],
            readingLog: log,
          ),
        );
      }

      for (final note in notes) {
        items.add(
          ReadingTimelineItem(
            type: ReadingTimelineItemType.memo,
            timestamp: note.updatedAt,
            book: bookMap[note.bookId],
            note: note,
          ),
        );
      }

      for (final action in actions) {
        items.add(
          ReadingTimelineItem(
            type: ReadingTimelineItemType.action,
            timestamp: action.updatedAt,
            book: action.bookId != null ? bookMap[action.bookId] : null,
            action: action,
          ),
        );
      }

      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = state.copyWith(items: AsyncValue.data(items));
    } catch (error, stackTrace) {
      state = state.copyWith(items: AsyncValue.error(error, stackTrace));
    }
  }
}

class ReadingTimelinePage extends ConsumerWidget {
  const ReadingTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(readingTimelineNotifierProvider);
    final notifier = ref.read(readingTimelineNotifierProvider.notifier);

    return AppPage(
      title: '読書タイムライン',
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      scrollable: true,
      currentDestination: AppDestination.home,
      actions: [
        IconButton(
          tooltip: '更新',
          onPressed: notifier.loadTimeline,
          icon: const Icon(AppIcons.refresh),
        )
      ],
      child: state.items.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: 'まだ履歴がありません',
              message: '読書ログやメモ、行動を追加するとここに表示されます。',
              icon: AppIcons.calendarViewWeek,
            );
          }
          return _TimelineList(items: items);
        },
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '履歴の取得中に問題が発生しました',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton.icon(
                onPressed: notifier.loadTimeline,
                icon: const Icon(AppIcons.refresh),
                label: const Text('再試行'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.items});

  final List<ReadingTimelineItem> items;

  List<_TimelineGroup> _groupByDate(List<ReadingTimelineItem> entries) {
    final grouped = <DateTime, List<ReadingTimelineItem>>{};

    for (final item in entries) {
      final dayKey = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      grouped.putIfAbsent(dayKey, () => []).add(item);
    }

    final groups = grouped.entries.map((entry) {
      entry.value.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return _TimelineGroup(date: entry.key, items: entry.value);
    }).toList();

    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _TimelineDateHeader(date: group.date),
          const SizedBox(height: AppSpacing.medium),
          ...[
            for (var index = 0; index < group.items.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == group.items.length - 1
                      ? AppSpacing.large
                      : AppSpacing.medium,
                ),
                child: _TimelineTile(
                  item: group.items[index],
                  isLast: index == group.items.length - 1,
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _TimelineDateHeader extends StatelessWidget {
  const _TimelineDateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy/MM/dd (E)', 'ja');
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

    return Row(
      children: [
        Text(
          formatter.format(date),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (isToday) ...[
          const SizedBox(width: AppSpacing.small),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.small,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: AppRadius.smallRadius,
            ),
            child: Text(
              'Today',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.item,
    required this.isLast,
  });

  final ReadingTimelineItem item;
  final bool isLast;

  String _iconForType() {
    switch (item.type) {
      case ReadingTimelineItemType.started:
      case ReadingTimelineItemType.reading:
        return '📘';
      case ReadingTimelineItemType.finished:
        return '🏁';
      case ReadingTimelineItemType.memo:
        return '📝';
      case ReadingTimelineItemType.action:
        return '💡';
    }
  }

  Color _accentColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (item.type) {
      case ReadingTimelineItemType.started:
        return colorScheme.primary;
      case ReadingTimelineItemType.finished:
        return colorScheme.tertiary;
      case ReadingTimelineItemType.memo:
        return colorScheme.secondary;
      case ReadingTimelineItemType.action:
        return colorScheme.error;
      case ReadingTimelineItemType.reading:
        return colorScheme.primary;
    }
  }

  String _title() {
    final bookTitle = item.book?.title ?? '本の情報なし';
    switch (item.type) {
      case ReadingTimelineItemType.started:
        return '「$bookTitle」を読み始めました';
      case ReadingTimelineItemType.finished:
        return '「$bookTitle」を読了しました';
      case ReadingTimelineItemType.memo:
        return 'メモを追加';
      case ReadingTimelineItemType.action:
        return '行動を登録: ${item.action?.title ?? ''}';
      case ReadingTimelineItemType.reading:
        final pages = _pagesRead(item.readingLog);
        if (pages != null) {
          return '「$bookTitle」を$pagesページ読書';
        }
        return '「$bookTitle」を読みました';
    }
  }

  String? _subtitle() {
    switch (item.type) {
      case ReadingTimelineItemType.memo:
        final content = item.note?.content.trim();
        if (content == null || content.isEmpty) return null;
        return content;
      case ReadingTimelineItemType.action:
        return item.action?.description;
      case ReadingTimelineItemType.reading:
        final log = item.readingLog;
        if (log == null) return null;
        final buffer = StringBuffer();
        if (log.startPage != null && log.endPage != null) {
          buffer.write('${log.startPage} → ${log.endPage} ページ');
        }
        if (log.durationMinutes != null) {
          if (buffer.isNotEmpty) buffer.write(' · ');
          buffer.write('${log.durationMinutes}分');
        }
        return buffer.isEmpty ? null : buffer.toString();
      case ReadingTimelineItemType.started:
      case ReadingTimelineItemType.finished:
        return null;
    }
  }

  int? _pagesRead(ReadingLogRow? log) {
    if (log?.startPage == null || log?.endPage == null) return null;
    final pages = log!.endPage! - log.startPage!;
    return pages > 0 ? pages : null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeLabel = DateFormat('HH:mm').format(item.timestamp);
    final subtitle = _subtitle();
    final accent = _accentColor(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _iconForType(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: AppSpacing.small),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.book != null) ...[
                              Text(
                                item.book!.title,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xSmall),
                            ],
                            Text(
                              _title(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Text(
                        timeLabel,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineGroup {
  const _TimelineGroup({
    required this.date,
    required this.items,
  });

  final DateTime date;
  final List<ReadingTimelineItem> items;
}
