import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/widgets/app_card.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/theme/tokens/text_styles.dart';
import '../../shared/constants/app_icons.dart';

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
    required this.monthlyPagePoints,
    required this.finishedBookPoints,
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
        monthlyPagePoints: [],
        finishedBookPoints: [],
        isLoading: true,
      );

  final List<BookRow> books;
  final List<ReadingLogWithBook> logs;
  final int dailyTotal;
  final int weeklyTotal;
  final int monthlyTotal;
  final List<MonthlyStatPoint> monthlyPagePoints;
  final List<MonthlyStatPoint> finishedBookPoints;
  final int? selectedBookId;
  final bool isLoading;
  final String? error;

  ReadingSpeedState copyWith({
    List<BookRow>? books,
    List<ReadingLogWithBook>? logs,
    int? dailyTotal,
    int? weeklyTotal,
    int? monthlyTotal,
    List<MonthlyStatPoint>? monthlyPagePoints,
    List<MonthlyStatPoint>? finishedBookPoints,
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
      monthlyPagePoints: monthlyPagePoints ?? this.monthlyPagePoints,
      finishedBookPoints: finishedBookPoints ?? this.finishedBookPoints,
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

class MonthlyStatPoint {
  const MonthlyStatPoint({required this.month, required this.value});

  final DateTime month;
  final int value;
}

class ReadingSpeedNotifier extends StateNotifier<ReadingSpeedState> {
  ReadingSpeedNotifier(this._repository) : super(ReadingSpeedState.initial());

  final LocalDatabaseRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final books = await _repository.getAllBooks();
      final logs = await _repository.getReadingLogs();
      final selectedBookId =
          state.selectedBookId ?? (books.isNotEmpty ? books.first.id : null);
      final enrichedLogs = logs
          .map(
            (log) => ReadingLogWithBook(
              log: log,
              book: books.cast<BookRow?>().firstWhere(
                  (book) => book?.id == log.bookId,
                  orElse: () => null),
            ),
          )
          .toList();

      final stats = _computeStats(enrichedLogs, books);

      state = state.copyWith(
        books: books,
        logs: enrichedLogs,
        selectedBookId: selectedBookId,
        dailyTotal: stats.dailyTotal,
        weeklyTotal: stats.weeklyTotal,
        monthlyTotal: stats.monthlyTotal,
        monthlyPagePoints: stats.monthlyPages,
        finishedBookPoints: stats.finishedBooks,
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

  _ReadingStats _computeStats(
    List<ReadingLogWithBook> logs,
    List<BookRow> books,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(today.year, today.month, 1);

    var dailyTotal = 0;
    var weeklyTotal = 0;
    var monthlyTotal = 0;

    final dailyMap = <DateTime, int>{};
    final monthlyPageMap = <DateTime, int>{};

    DateTime monthKey(DateTime date) => DateTime(date.year, date.month);

    for (final entry in logs) {
      final logDate = DateTime(
        entry.log.loggedAt.year,
        entry.log.loggedAt.month,
        entry.log.loggedAt.day,
      );
      final pages = _pagesRead(entry.log);

      dailyMap[logDate] = (dailyMap[logDate] ?? 0) + pages;
      final month = monthKey(logDate);
      monthlyPageMap[month] = (monthlyPageMap[month] ?? 0) + pages;

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

    return _ReadingStats(
      dailyTotal: dailyTotal,
      weeklyTotal: weeklyTotal,
      monthlyTotal: monthlyTotal,
      monthlyPages: _buildMonthlyPoints(now, monthlyPageMap),
      finishedBooks: _buildFinishedBookPoints(now, books),
    );
  }

  List<MonthlyStatPoint> _buildMonthlyPoints(
    DateTime now,
    Map<DateTime, int> monthlyTotals,
  ) {
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index), 1),
    );

    return months
        .map(
          (month) => MonthlyStatPoint(
            month: month,
            value: monthlyTotals[month] ?? 0,
          ),
        )
        .toList();
  }

  List<MonthlyStatPoint> _buildFinishedBookPoints(
    DateTime now,
    List<BookRow> books,
  ) {
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index), 1),
    );

    final finishedCounts = <DateTime, int>{};

    for (final book in books) {
      if (book.finishedAt == null) {
        continue;
      }

      final status = bookStatusFromDbValue(book.status);
      if (status != BookStatus.finished) {
        continue;
      }

      final finishedMonth =
          DateTime(book.finishedAt!.year, book.finishedAt!.month, 1);
      finishedCounts[finishedMonth] = (finishedCounts[finishedMonth] ?? 0) + 1;
    }

    return months
        .map(
          (month) => MonthlyStatPoint(
            month: month,
            value: finishedCounts[month] ?? 0,
          ),
        )
        .toList();
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
    required this.monthlyPages,
    required this.finishedBooks,
  });

  final int dailyTotal;
  final int weeklyTotal;
  final int monthlyTotal;
  final List<MonthlyStatPoint> monthlyPages;
  final List<MonthlyStatPoint> finishedBooks;
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
          onRefresh: () =>
              ref.read(readingSpeedNotifierProvider.notifier).load(),
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                  ? _ErrorCard(message: state.error!)
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      children: [
                        _SummarySection(state: state),
                        const SizedBox(height: 16),
                        _AnalyticsSection(state: state),
                        const SizedBox(height: 16),
                        _ReadingLogForm(
                          state: state,
                          pagesController: _pagesController,
                          durationController: _durationController,
                        ),
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
            icon: AppIcons.today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: _SummaryCard(
            title: '今週',
            value: '${state.weeklyTotal} ページ',
            icon: AppIcons.calendarViewWeek,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: _SummaryCard(
            title: '今月',
            value: '${state.monthlyTotal} ページ',
            icon: AppIcons.calendarMonth,
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
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.small),
                Text(
                  title,
                  style: AppTextStyles.title(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              value,
              style: AppTextStyles.pageTitle(context).copyWith(
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
        icon: AppIcons.menuBook,
        message: 'まずは検索から本を登録して読書ログを追加しましょう',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '読書ログを追加',
              style: AppTextStyles.title(context),
            ),
            const SizedBox(height: AppSpacing.medium),
            DropdownButtonFormField<int>(
              initialValue: state.selectedBookId,
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
                  ref
                      .read(readingSpeedNotifierProvider.notifier)
                      .selectBook(bookId);
                }
              },
            ),
            const SizedBox(height: AppSpacing.medium),
            TextField(
              controller: pagesController,
              decoration: const InputDecoration(
                labelText: '読んだページ数',
                hintText: '例: 25',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.medium),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(
                labelText: '読書時間（分）',
                hintText: '例: 30',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.medium),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(AppIcons.saveAlt),
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
    final selectedBookId =
        ref.read(readingSpeedNotifierProvider).selectedBookId;
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

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({required this.state});

  final ReadingSpeedState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '読書分析',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '直近6か月の読書傾向を確認しましょう',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: '月間読書ページ数',
          subtitle: '直近6か月の推移',
          child: _MonthlyPagesChart(points: state.monthlyPagePoints),
        ),
        const SizedBox(height: 12),
        _ChartCard(
          title: '読了冊数',
          subtitle: '完読した冊数の推移',
          child: _FinishedBooksChart(points: state.finishedBookPoints),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(18);

    final baseColor = Color.lerp(
            colorScheme.surface, colorScheme.surfaceContainerHighest, 0.24) ??
        colorScheme.surface;

    return Card(
      elevation: 1.5,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      color: baseColor,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MonthlyPagesChart extends StatelessWidget {
  const _MonthlyPagesChart({required this.points});

  final List<MonthlyStatPoint> points;

  bool get _hasData => points.any((point) => point.value > 0);

  double _maxY() {
    if (!_hasData) {
      return 10;
    }

    final maxPages = points.map((point) => point.value).reduce(max).toDouble();
    if (maxPages <= 50) return 50;
    if (maxPages <= 100) return 100;
    return (maxPages / 50).ceil() * 50;
  }

  double _interval(double maxY) {
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    return 25;
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || !_hasData) {
      return const _EmptyChartMessage(
        icon: AppIcons.barChart,
        message: 'まだページ数の記録がありません',
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final maxY = _maxY();
    final interval = _interval(maxY);

    final lineColor =
        Color.lerp(colorScheme.primary, colorScheme.secondary, 0.2) ??
            colorScheme.primary;
    final gridColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
    final labelColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: gridColor,
              strokeWidth: 1,
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) =>
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
              tooltipRoundedRadius: 12,
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final point = points[spot.x.toInt()];
                return LineTooltipItem(
                  '${point.month.month}月\n',
                  textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                  children: [
                    TextSpan(
                      text: '${point.value} ページ',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final point = points[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${point.month.month}月',
                      style: textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toInt().toString(),
                    style: textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 3,
              color: lineColor,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: colorScheme.surface,
                  strokeColor: lineColor,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: 0.26),
                    lineColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: points
                  .asMap()
                  .entries
                  .map((entry) => FlSpot(
                        entry.key.toDouble(),
                        entry.value.value.toDouble(),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedBooksChart extends StatelessWidget {
  const _FinishedBooksChart({required this.points});

  final List<MonthlyStatPoint> points;

  bool get _hasData => points.any((point) => point.value > 0);

  double _maxY() {
    if (!_hasData) {
      return 2;
    }

    final maxCount = points.map((point) => point.value).reduce(max).toDouble();
    return (maxCount + 1).ceilToDouble();
  }

  double _interval(double maxY) {
    if (maxY <= 3) return 1;
    if (maxY <= 6) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || !_hasData) {
      return const _EmptyChartMessage(
        icon: AppIcons.book,
        message: 'まだ読了冊数のデータがありません',
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final maxY = _maxY();
    final interval = _interval(maxY);

    final barColor = Color.lerp(
          colorScheme.secondary,
          colorScheme.primary,
          0.15,
        ) ??
        colorScheme.secondary;
    final gridColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
    final labelColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: gridColor,
              strokeWidth: 1,
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 12,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              getTooltipColor: (group) =>
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = points[groupIndex];
                return BarTooltipItem(
                  '${point.month.month}月\n',
                  textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                  children: [
                    TextSpan(
                      text: '${point.value} 冊',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final point = points[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${point.month.month}月',
                      style: textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toInt().toString(),
                    style: textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          maxY: maxY,
          minY: 0,
          barGroups: points.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: point.value.toDouble(),
                  width: 18,
                  color: barColor,
                  borderRadius: BorderRadius.circular(8),
                  rodStackItems: [
                    BarChartRodStackItem(
                      0,
                      point.value.toDouble(),
                      barColor.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  const _EmptyChartMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
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
        icon: AppIcons.book,
        message: '記録はまだありません。ページ数を入力して記録しましょう。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近の記録',
          style: AppTextStyles.title(context),
        ),
        const SizedBox(height: AppSpacing.medium),
        ...logs.map((entry) {
          final localization = MaterialLocalizations.of(context);
          final logDate = entry.log.loggedAt.toLocal();
          final dateLabel = localization.formatShortDate(logDate);
          final pages =
              max(0, (entry.log.endPage ?? 0) - (entry.log.startPage ?? 0));

          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.book?.title ?? '不明な本',
                        style: AppTextStyles.title(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (entry.log.durationMinutes != null)
                      Chip(
                        label: Text('${entry.log.durationMinutes} 分'),
                        avatar: const Icon(AppIcons.timelapse,
                            size: AppIconSizes.small),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),
                Row(
                  children: [
                    Icon(
                      AppIcons.today,
                      size: AppIconSizes.small,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      '$dateLabel · $pages ページ',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
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
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          children: [
            Icon(icon, size: AppIconSizes.large),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium(context),
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
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.error, color: Colors.red),
              const SizedBox(height: AppSpacing.small),
              Text(
                '読み込みに失敗しました',
                style: AppTextStyles.title(context).copyWith(color: Colors.red),
              ),
              const SizedBox(height: AppSpacing.small),
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
