import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../shared/constants/app_icons.dart';

final statisticsNotifierProvider =
    StateNotifierProvider<StatisticsNotifier, StatisticsState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return StatisticsNotifier(repository)..load();
});

class StatisticsState {
  const StatisticsState({
    required this.monthlyFinishedBooks,
    required this.monthlyPages,
    required this.pacePoints,
    this.averageCompletionDays,
    this.isLoading = false,
    this.error,
  });

  factory StatisticsState.initial() => const StatisticsState(
        monthlyFinishedBooks: 0,
        monthlyPages: 0,
        pacePoints: [],
        isLoading: true,
      );

  final int monthlyFinishedBooks;
  final int monthlyPages;
  final double? averageCompletionDays;
  final List<DailyPacePoint> pacePoints;
  final bool isLoading;
  final String? error;

  StatisticsState copyWith({
    int? monthlyFinishedBooks,
    int? monthlyPages,
    double? averageCompletionDays,
    List<DailyPacePoint>? pacePoints,
    bool? isLoading,
    String? error,
  }) {
    return StatisticsState(
      monthlyFinishedBooks: monthlyFinishedBooks ?? this.monthlyFinishedBooks,
      monthlyPages: monthlyPages ?? this.monthlyPages,
      averageCompletionDays:
          averageCompletionDays ?? this.averageCompletionDays,
      pacePoints: pacePoints ?? this.pacePoints,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DailyPacePoint {
  const DailyPacePoint({required this.date, required this.pages});

  final DateTime date;
  final int pages;
}

class StatisticsNotifier extends StateNotifier<StatisticsState> {
  StatisticsNotifier(this._repository) : super(StatisticsState.initial());

  final LocalDatabaseRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final books = await _repository.getAllBooks();
      final logs = await _repository.getReadingLogs();

      final snapshot = _calculateStats(books, logs);

      state = state.copyWith(
        monthlyFinishedBooks: snapshot.monthlyFinishedBooks,
        monthlyPages: snapshot.monthlyPages,
        averageCompletionDays: snapshot.averageCompletionDays,
        pacePoints: snapshot.pacePoints,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  _StatisticsSnapshot _calculateStats(
    List<BookRow> books,
    List<ReadingLogRow> logs,
  ) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    var monthlyPages = 0;
    for (final log in logs) {
      if (log.loggedAt.isBefore(startOfMonth)) {
        continue;
      }
      monthlyPages += _pagesRead(log);
    }

    final monthlyFinishedBooks = books.where((book) {
      if (book.finishedAt == null) {
        return false;
      }
      final status = bookStatusFromDbValue(book.status);
      if (status != BookStatus.finished) {
        return false;
      }
      return book.finishedAt!.year == now.year &&
          book.finishedAt!.month == now.month;
    }).length;

    final completionDurations = books.where((book) {
      final status = bookStatusFromDbValue(book.status);
      return status == BookStatus.finished &&
          book.startedAt != null &&
          book.finishedAt != null;
    }).map((book) {
      final duration = book.finishedAt!.difference(book.startedAt!);
      // Include both start and finish days.
      return duration.inDays + 1;
    }).toList();

    final averageCompletionDays = completionDurations.isEmpty
        ? null
        : completionDurations.reduce((a, b) => a + b) /
            completionDurations.length;

    final pacePoints = _buildPacePoints(now, logs);

    return _StatisticsSnapshot(
      monthlyFinishedBooks: monthlyFinishedBooks,
      monthlyPages: monthlyPages,
      averageCompletionDays: averageCompletionDays,
      pacePoints: pacePoints,
    );
  }

  List<DailyPacePoint> _buildPacePoints(
    DateTime now,
    List<ReadingLogRow> logs,
  ) {
    final days = List.generate(
      14,
      (index) {
        final day = now.subtract(Duration(days: 13 - index));
        return DateTime(day.year, day.month, day.day);
      },
    );

    final dailyTotals = <DateTime, int>{};
    for (final log in logs) {
      final day = DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
      dailyTotals[day] = (dailyTotals[day] ?? 0) + _pagesRead(log);
    }

    return days
        .map((day) =>
            DailyPacePoint(date: day, pages: dailyTotals[day] ?? 0))
        .toList();
  }

  int _pagesRead(ReadingLogRow log) {
    final start = log.startPage ?? 0;
    final end = log.endPage ?? 0;
    return max(0, end - start);
  }
}

class _StatisticsSnapshot {
  const _StatisticsSnapshot({
    required this.monthlyFinishedBooks,
    required this.monthlyPages,
    required this.averageCompletionDays,
    required this.pacePoints,
  });

  final int monthlyFinishedBooks;
  final int monthlyPages;
  final double? averageCompletionDays;
  final List<DailyPacePoint> pacePoints;
}

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsNotifierProvider);
    final notifier = ref.read(statisticsNotifierProvider.notifier);

    return AppPage(
      title: '読書統計',
      actions: [
        IconButton(
          tooltip: '更新',
          onPressed: () => notifier.load(),
          icon: const Icon(AppIcons.refresh),
        ),
      ],
      scrollable: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: state.isLoading
            ? const LoadingIndicator()
            : state.error != null
                ? _ErrorView(message: state.error!)
                : _StatisticsView(state: state),
      ),
    );
  }
}

class _StatisticsView extends StatelessWidget {
  const _StatisticsView({required this.state});

  final StatisticsState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(state: state),
        const SizedBox(height: AppSpacing.large),
        _PaceSection(points: state.pacePoints),
        const SizedBox(height: AppSpacing.large),
        const _GenrePlaceholder(),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.state});

  final StatisticsState state;

  String _averageLabel() {
    if (state.averageCompletionDays == null) {
      return '-';
    }
    final days = state.averageCompletionDays!;
    if (days == days.roundToDouble()) {
      return '${days.toInt()}日';
    }
    return '${days.toStringAsFixed(1)}日';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 640;
        final spacing = isWide ? AppSpacing.large : AppSpacing.medium;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: isWide ? constraints.maxWidth / 2 - spacing / 2 : double.infinity,
              child: _MetricCard(
                title: '今月の読了冊数',
                value: '${state.monthlyFinishedBooks} 冊',
                icon: AppIcons.menuBook,
                iconColor: Colors.indigo,
              ),
            ),
            SizedBox(
              width: isWide ? constraints.maxWidth / 2 - spacing / 2 : double.infinity,
              child: _MetricCard(
                title: '今月の読書ページ',
                value: '${state.monthlyPages} ページ',
                icon: AppIcons.barChart,
                iconColor: Colors.deepPurple,
              ),
            ),
            SizedBox(
              width: isWide ? constraints.maxWidth / 2 - spacing / 2 : double.infinity,
              child: _MetricCard(
                title: '平均読了日数',
                value: _averageLabel(),
                icon: AppIcons.timelapse,
                iconColor: Colors.teal,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceSection extends StatelessWidget {
  const _PaceSection({required this.points});

  final List<DailyPacePoint> points;

  bool get _hasData => points.any((point) => point.pages > 0);

  double _maxY() {
    if (!_hasData) {
      return 10;
    }
    final maxPages = points.map((point) => point.pages).reduce(max).toDouble();
    if (maxPages <= 30) return 30;
    if (maxPages <= 60) return 60;
    return (maxPages / 20).ceil() * 20;
  }

  double _interval(double maxY) {
    if (maxY <= 30) return 10;
    if (maxY <= 60) return 20;
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _maxY();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ペース推移',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '直近2週間',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          if (points.isEmpty || !_hasData)
            const _EmptyChartMessage(
              icon: AppIcons.speed,
              message: '読書記録がまだありません',
            )
          else
            _PaceChart(points: points, maxY: maxY, interval: _interval(maxY)),
        ],
      ),
    );
  }
}

class _PaceChart extends StatelessWidget {
  const _PaceChart({
    required this.points,
    required this.maxY,
    required this.interval,
  });

  final List<DailyPacePoint> points;
  final double maxY;
  final double interval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final lineColor = Color.lerp(
          colorScheme.primary,
          colorScheme.secondary,
          0.2,
        ) ??
        colorScheme.primary;
    final gridColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
    final labelColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.9);
    final dateFormat = DateFormat('M/d');

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: gridColor,
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: gridColor,
              strokeWidth: 1,
            ),
            horizontalInterval: interval,
            verticalInterval: 2,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final date = points[index].date;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      dateFormat.format(date),
                      style: textTheme.labelSmall?.copyWith(color: labelColor),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toInt().toString(),
                    style: textTheme.labelSmall?.copyWith(color: labelColor),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final point = points[spot.x.toInt()];
                  return LineTooltipItem(
                    '${dateFormat.format(point.date)}\n${point.pages} ページ',
                    textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points
                  .asMap()
                  .entries
                  .map((entry) => FlSpot(entry.key.toDouble(), entry.value.pages.toDouble()))
                  .toList(),
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.15),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.small),
          Flexible(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenrePlaceholder extends StatelessWidget {
  const _GenrePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.goal, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.small),
              Text(
                'ジャンル別傾向',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'ジャンル別の読書傾向はまもなく追加予定です。',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error, color: colorScheme.error),
            const SizedBox(height: AppSpacing.small),
            Text(
              '統計情報の取得に失敗しました',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
