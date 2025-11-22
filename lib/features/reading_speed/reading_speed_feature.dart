import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';

final readingSpeedNotifierProvider =
    StateNotifierProvider<ReadingSpeedNotifier, ReadingSpeedState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return ReadingSpeedNotifier(repository)..load();
});

class ReadingSpeedState {
  const ReadingSpeedState({
    required this.books,
    required this.logs,
    required this.dailyTotal,
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.recentDailyPoints,
    this.selectedBookId,
    this.isLoading = false,
    this.error,
  });

  factory ReadingSpeedState.initial() => const ReadingSpeedState(
        books: [],
        logs: [],
        dailyTotal: 0,
        weeklyTotal: 0,
        monthlyTotal: 0,
        recentDailyPoints: [],
        isLoading: true,
      );

  final List<BookRow> books;
  final List<ReadingLogWithBook> logs;
  final int dailyTotal;
  final int weeklyTotal;
  final int monthlyTotal;
  final List<ReadingStatPoint> recentDailyPoints;
  final int? selectedBookId;
  final bool isLoading;
  final String? error;

  ReadingSpeedState copyWith({
    List<BookRow>? books,
    List<ReadingLogWithBook>? logs,
    int? dailyTotal,
    int? weeklyTotal,
    int? monthlyTotal,
    List<ReadingStatPoint>? recentDailyPoints,
    int? selectedBookId,
    bool? isLoading,
    String? error,
  }) {
    return ReadingSpeedState(
      books: books ?? this.books,
      logs: logs ?? this.logs,
      dailyTotal: dailyTotal ?? this.dailyTotal,
      weeklyTotal: weeklyTotal ?? this.weeklyTotal,
      monthlyTotal: monthlyTotal ?? this.monthlyTotal,
      recentDailyPoints: recentDailyPoints ?? this.recentDailyPoints,
      selectedBookId: selectedBookId ?? this.selectedBookId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReadingLogWithBook {
  ReadingLogWithBook({required this.log, this.book});

  final ReadingLogRow log;
  final BookRow? book;
}

class ReadingStatPoint {
  const ReadingStatPoint({required this.date, required this.pages});

  final DateTime date;
  final int pages;
}

class ReadingSpeedNotifier extends StateNotifier<ReadingSpeedState> {
  ReadingSpeedNotifier(this._repository) : super(ReadingSpeedState.initial());

  final LocalDatabaseRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final books = await _repository.getAllBooks();
      final logs = await _repository.getReadingLogs();
      final selectedBookId = state.selectedBookId ??
          (books.isNotEmpty ? books.first.id : null);
      final enrichedLogs = logs
          .map(
            (log) => ReadingLogWithBook(
              log: log,
              book: books
                  .cast<BookRow?>()
                  .firstWhere((book) => book?.id == log.bookId,
                      orElse: () => null),
            ),
          )
          .toList();

      final stats = _computeStats(enrichedLogs);

      state = state.copyWith(
        books: books,
        logs: enrichedLogs,
        selectedBookId: selectedBookId,
        dailyTotal: stats.dailyTotal,
        weeklyTotal: stats.weeklyTotal,
        monthlyTotal: stats.monthlyTotal,
        recentDailyPoints: stats.recentPoints,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void selectBook(int bookId) {
    state = state.copyWith(selectedBookId: bookId);
  }

  Future<void> addReadingLog({
    required int bookId,
    required int pagesRead,
    int? durationMinutes,
  }) async {
    await _repository.addReadingLog(
      bookId: bookId,
      pagesRead: pagesRead,
      durationMinutes: durationMinutes,
    );
    await load();
    state = state.copyWith(selectedBookId: bookId);
  }

  _ReadingStats _computeStats(List<ReadingLogWithBook> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(today.year, today.month, 1);

    var dailyTotal = 0;
    var weeklyTotal = 0;
    var monthlyTotal = 0;

    final dailyMap = <DateTime, int>{};

    for (final entry in logs) {
      final logDate = DateTime(
        entry.log.loggedAt.year,
        entry.log.loggedAt.month,
        entry.log.loggedAt.day,
      );
      final pages = _pagesRead(entry.log);

      dailyMap[logDate] = (dailyMap[logDate] ?? 0) + pages;

      if (logDate == today) {
        dailyTotal += pages;
      }

      if (!logDate.isBefore(today.subtract(const Duration(days: 6)))) {
        weeklyTotal += pages;
      }

      if (!logDate.isBefore(startOfMonth)) {
        monthlyTotal += pages;
      }
    }

    final recentDates = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    final points = recentDates
        .map(
          (date) => ReadingStatPoint(
            date: date,
            pages: dailyMap[date] ?? 0,
          ),
        )
        .toList();

    return _ReadingStats(
      dailyTotal: dailyTotal,
      weeklyTotal: weeklyTotal,
      monthlyTotal: monthlyTotal,
      recentPoints: points,
    );
  }

  int _pagesRead(ReadingLogRow log) {
    final start = log.startPage ?? 0;
    final end = log.endPage ?? 0;
    return max(0, end - start);
  }
}

class _ReadingStats {
  _ReadingStats({
    required this.dailyTotal,
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.recentPoints,
  });

  final int dailyTotal;
  final int weeklyTotal;
  final int monthlyTotal;
  final List<ReadingStatPoint> recentPoints;
}

class ReadingSpeedPage extends ConsumerStatefulWidget {
  const ReadingSpeedPage({super.key});

  @override
  ConsumerState<ReadingSpeedPage> createState() => _ReadingSpeedPageState();
}

class _ReadingSpeedPageState extends ConsumerState<ReadingSpeedPage> {
  final _pagesController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void dispose() {
    _pagesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingSpeedNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('読書速度'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(readingSpeedNotifierProvider.notifier).load(),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                  ? _ErrorCard(message: state.error!)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SummarySection(state: state),
                        const SizedBox(height: 16),
                        _ReadingLogForm(
                          state: state,
                          pagesController: _pagesController,
                          durationController: _durationController,
                        ),
                        const SizedBox(height: 16),
                        _ReadingChart(points: state.recentDailyPoints),
                        const SizedBox(height: 16),
                        _ReadingLogList(logs: state.logs),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.state});

  final ReadingSpeedState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: '今日',
            value: '${state.dailyTotal} ページ',
            icon: Icons.today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: '今週',
            value: '${state.weeklyTotal} ページ',
            icon: Icons.calendar_view_week,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: '今月',
            value: '${state.monthlyTotal} ページ',
            icon: Icons.calendar_month,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingLogForm extends ConsumerWidget {
  const _ReadingLogForm({
    required this.state,
    required this.pagesController,
    required this.durationController,
  });

  final ReadingSpeedState state;
  final TextEditingController pagesController;
  final TextEditingController durationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.books.isEmpty) {
      return const _InfoCard(
        icon: Icons.menu_book_outlined,
        message: 'まずは検索から本を登録して読書ログを追加しましょう',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '読書ログを追加',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: state.selectedBookId,
              decoration: const InputDecoration(
                labelText: '本を選択',
                border: OutlineInputBorder(),
              ),
              items: state.books
                  .map(
                    (book) => DropdownMenuItem(
                      value: book.id,
                      child: Text(book.title),
                    ),
                  )
                  .toList(),
              onChanged: (bookId) {
                if (bookId != null) {
                  ref.read(readingSpeedNotifierProvider.notifier)
                      .selectBook(bookId);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pagesController,
              decoration: const InputDecoration(
                labelText: '読んだページ数',
                hintText: '例: 25',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(
                labelText: '読書時間（分）',
                hintText: '例: 30',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('記録する'),
                onPressed: () => _submit(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final selectedBookId = ref.read(readingSpeedNotifierProvider).selectedBookId;
    if (selectedBookId == null) {
      return;
    }

    final pages = int.tryParse(pagesController.text.trim());
    final duration = int.tryParse(durationController.text.trim());

    if (pages == null || pages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('読んだページ数を正しく入力してください')),
      );
      return;
    }

    await ref.read(readingSpeedNotifierProvider.notifier).addReadingLog(
          bookId: selectedBookId,
          pagesRead: pages,
          durationMinutes: duration,
        );

    pagesController.clear();
    durationController.clear();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('読書ログを追加しました')),
      );
    }
  }
}

class _ReadingChart extends StatelessWidget {
  const _ReadingChart({required this.points});

  final List<ReadingStatPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxPages = points.isEmpty
        ? 0
        : points.map((point) => point.pages).reduce(max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '直近1週間の推移',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              const _InfoCard(
                icon: Icons.bar_chart,
                message: 'まだ読書ログがありません',
              )
            else
              SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: points.map((point) {
                    final height = maxPages == 0
                        ? 0.0
                        : (point.pages / maxPages) * 140;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${point.pages}',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Container(
                            height: max(height, 6),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${point.date.month}/${point.date.day}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadingLogList extends StatelessWidget {
  const _ReadingLogList({required this.logs});

  final List<ReadingLogWithBook> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const _InfoCard(
        icon: Icons.book_outlined,
        message: '記録はまだありません。ページ数を入力して記録しましょう。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近の記録',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...logs.map((entry) {
          final localization = MaterialLocalizations.of(context);
          final logDate = entry.log.loggedAt.toLocal();
          final dateLabel = localization.formatShortDate(logDate);
          final pages =
              max(0, (entry.log.endPage ?? 0) - (entry.log.startPage ?? 0));

          return Card(
            child: ListTile(
              title: Text(entry.book?.title ?? '不明な本'),
              subtitle: Text('$dateLabel · $pages ページ'),
              trailing: entry.log.durationMinutes != null
                  ? Text('${entry.log.durationMinutes} 分')
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                '読み込みに失敗しました',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
