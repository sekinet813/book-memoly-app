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
    required this.snapshot,
    this.selectedRange = StatisticsRange.monthly,
    this.isLoading = false,
    this.error,
  });

  factory StatisticsState.initial() => const StatisticsState(
        snapshot: _StatisticsSnapshot.empty(),
        isLoading: true,
      );

  final _StatisticsSnapshot snapshot;
  final StatisticsRange selectedRange;
  final bool isLoading;
  final String? error;

  StatisticsState copyWith({
    _StatisticsSnapshot? snapshot,
    StatisticsRange? selectedRange,
    bool? isLoading,
    String? error,
  }) {
    return StatisticsState(
      snapshot: snapshot ?? this.snapshot,
      selectedRange: selectedRange ?? this.selectedRange,
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

class GenreRatio {
  const GenreRatio({
    required this.name,
    required this.count,
    required this.percentage,
  });

  final String name;
  final int count;
  final double percentage;
}

class BarValue {
  const BarValue({required this.label, required this.value});

  final String label;
  final int value;
}

class StreakStats {
  const StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.longestGap,
  });

  final int currentStreak;
  final int longestStreak;
  final int longestGap;
}

class BestReadingPeriod {
  const BestReadingPeriod({required this.label, required this.pages});

  final String label;
  final int pages;
}

enum StatisticsRange { monthly, all }

class StatisticsNotifier extends StateNotifier<StatisticsState> {
  StatisticsNotifier(this._repository) : super(StatisticsState.initial());

  final LocalDatabaseRepository _repository;
  List<BookRow> _books = [];
  List<ReadingLogRow> _logs = [];
  Map<int, List<TagRow>> _bookTags = {};

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      _books = await _repository.getAllBooks();
      _logs = await _repository.getReadingLogs();
      _bookTags = await _repository.getTagsForBooks(
        _books.map((book) => book.id).toList(),
      );

      final snapshot = _calculateStats(state.selectedRange);

      state = state.copyWith(
        snapshot: snapshot,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void changeRange(StatisticsRange range) {
    if (range == state.selectedRange) {
      return;
    }

    final snapshot = _calculateStats(range);
    state = state.copyWith(snapshot: snapshot, selectedRange: range);
  }

  _StatisticsSnapshot _calculateStats(StatisticsRange range) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final rangeStart =
        range == StatisticsRange.monthly ? startOfMonth : DateTime(1970);

    final filteredLogs = _logs
        .where((log) => !log.loggedAt.isBefore(rangeStart))
        .toList();
    final filteredBooks = _books.where((book) {
      if (range == StatisticsRange.all) {
        return true;
      }
      return book.finishedAt != null &&
          book.finishedAt!.year == now.year &&
          book.finishedAt!.month == now.month;
    }).toList();

    final totalPages = filteredLogs.fold<int>(0, (sum, log) {
      return sum + _pagesRead(log);
    });

    final finishedBooks = filteredBooks.where((book) {
      final status = bookStatusFromDbValue(book.status);
      return status == BookStatus.finished && book.finishedAt != null;
    }).length;

    final completionDurations = filteredBooks.where((book) {
      final status = bookStatusFromDbValue(book.status);
      return status == BookStatus.finished &&
          book.startedAt != null &&
          book.finishedAt != null;
    }).map((book) {
      final duration = book.finishedAt!.difference(book.startedAt!);
      return duration.inDays + 1;
    }).toList();

    final averageCompletionDays = completionDurations.isEmpty
        ? null
        : completionDurations.reduce((a, b) => a + b) /
            completionDurations.length;

    final pacePoints = _buildPacePoints(now, filteredLogs);
    final averageSpeed = _calculateAverageSpeed(filteredLogs);
    final weekdayBreakdown = _buildWeekdayBreakdown(filteredLogs);
    final hourlyBreakdown = _buildHourlyBreakdown(filteredLogs);
    final bestWeekday = _calculateBestPeriod(weekdayBreakdown);
    final bestHour = _calculateBestPeriod(hourlyBreakdown);
    final genreRatios = _buildGenreRatios(filteredBooks);
    final streak = _calculateStreak(filteredLogs, now);

    return _StatisticsSnapshot(
      finishedBooks: finishedBooks,
      pages: totalPages,
      averageCompletionDays: averageCompletionDays,
      pacePoints: pacePoints,
      averageReadingSpeed: averageSpeed,
      weekdayBreakdown: weekdayBreakdown,
      hourlyBreakdown: hourlyBreakdown,
      bestWeekday: bestWeekday,
      bestHour: bestHour,
      genreRatios: genreRatios,
      streak: streak,
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

  double? _calculateAverageSpeed(List<ReadingLogRow> logs) {
    var totalPages = 0;
    var totalMinutes = 0;

    for (final log in logs) {
      if (log.durationMinutes == null || log.durationMinutes == 0) {
        continue;
      }

      final pages = _pagesRead(log);
      if (pages <= 0) continue;

      totalPages += pages;
      totalMinutes += log.durationMinutes!;
    }

    if (totalMinutes == 0) {
      return null;
    }

    return totalPages / totalMinutes * 60;
  }

  List<BarValue> _buildWeekdayBreakdown(List<ReadingLogRow> logs) {
    const weekdayLabels = {
      DateTime.monday: '月',
      DateTime.tuesday: '火',
      DateTime.wednesday: '水',
      DateTime.thursday: '木',
      DateTime.friday: '金',
      DateTime.saturday: '土',
      DateTime.sunday: '日',
    };

    final totals = <int, int>{};
    for (final log in logs) {
      totals[log.loggedAt.weekday] =
          (totals[log.loggedAt.weekday] ?? 0) + _pagesRead(log);
    }

    return weekdayLabels.entries
        .map(
          (entry) => BarValue(
            label: entry.value,
            value: totals[entry.key] ?? 0,
          ),
        )
        .toList();
  }

  List<BarValue> _buildHourlyBreakdown(List<ReadingLogRow> logs) {
    final totals = <int, int>{};
    for (final log in logs) {
      totals[log.loggedAt.hour] =
          (totals[log.loggedAt.hour] ?? 0) + _pagesRead(log);
    }

    return List.generate(24, (index) {
      return BarValue(label: '$index', value: totals[index] ?? 0);
    });
  }

  BestReadingPeriod? _calculateBestPeriod(List<BarValue> values) {
    if (values.isEmpty) return null;
    final best = values.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value == 0) return null;
    return BestReadingPeriod(label: best.label, pages: best.value);
  }

  List<GenreRatio> _buildGenreRatios(List<BookRow> books) {
    final counts = <String, int>{};

    for (final book in books) {
      final tags = _bookTags[book.id] ?? const [];
      for (final tag in tags) {
        counts[tag.name] = (counts[tag.name] ?? 0) + 1;
      }
    }

    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return const [];
    }

    return counts.entries
        .map(
          (entry) => GenreRatio(
            name: entry.key,
            count: entry.value,
            percentage: entry.value / total * 100,
          ),
        )
        .toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  StreakStats _calculateStreak(
    List<ReadingLogRow> logs,
    DateTime now,
  ) {
    final readingDays = logs
        .where((log) => _pagesRead(log) > 0)
        .map((log) => DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day))
        .toSet()
        .toList()
      ..sort();

    if (readingDays.isEmpty) {
      return const StreakStats(currentStreak: 0, longestStreak: 0, longestGap: 0);
    }

    var longestStreak = 1;
    var currentStreak = 1;
    var longestGap = 0;

    for (var i = 1; i < readingDays.length; i++) {
      final previous = readingDays[i - 1];
      final current = readingDays[i];
      final diff = current.difference(previous).inDays;

      if (diff == 1) {
        currentStreak += 1;
      } else {
        longestStreak = max(longestStreak, currentStreak);
        currentStreak = 1;
        longestGap = max(longestGap, diff - 1);
      }
    }

    longestStreak = max(longestStreak, currentStreak);

    final today = DateTime(now.year, now.month, now.day);
    final lastReadingDay = readingDays.last;
    if (today.difference(lastReadingDay).inDays != 0) {
      currentStreak = 0;
    }

    return StreakStats(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      longestGap: longestGap,
    );
  }
}

class _StatisticsSnapshot {
  const _StatisticsSnapshot({
    required this.finishedBooks,
    required this.pages,
    required this.averageCompletionDays,
    required this.pacePoints,
    required this.averageReadingSpeed,
    required this.genreRatios,
    required this.streak,
    required this.weekdayBreakdown,
    required this.hourlyBreakdown,
    this.bestWeekday,
    this.bestHour,
  });

  const _StatisticsSnapshot.empty()
      : finishedBooks = 0,
        pages = 0,
        averageCompletionDays = null,
        pacePoints = const [],
        averageReadingSpeed = null,
        bestWeekday = null,
        bestHour = null,
        genreRatios = const [],
        weekdayBreakdown = const [],
        hourlyBreakdown = const [],
        streak = const StreakStats(
          currentStreak: 0,
          longestStreak: 0,
          longestGap: 0,
        );

  final int finishedBooks;
  final int pages;
  final double? averageCompletionDays;
  final List<DailyPacePoint> pacePoints;
  final double? averageReadingSpeed;
  final BestReadingPeriod? bestWeekday;
  final BestReadingPeriod? bestHour;
  final List<GenreRatio> genreRatios;
  final List<BarValue> weekdayBreakdown;
  final List<BarValue> hourlyBreakdown;
  final StreakStats streak;
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

class _StatisticsView extends ConsumerWidget {
  const _StatisticsView({required this.state});

  final StatisticsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = state.snapshot;
    final notifier = ref.read(statisticsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RangeSelector(
          selectedRange: state.selectedRange,
          onChanged: notifier.changeRange,
        ),
        const SizedBox(height: AppSpacing.large),
        _SummaryRow(range: state.selectedRange, snapshot: snapshot),
        const SizedBox(height: AppSpacing.large),
        _PaceSection(points: snapshot.pacePoints),
        const SizedBox(height: AppSpacing.large),
        _BestTimeSection(
          bestHour: snapshot.bestHour,
          bestWeekday: snapshot.bestWeekday,
          hourly: snapshot.hourlyBreakdown,
          weekday: snapshot.weekdayBreakdown,
        ),
        const SizedBox(height: AppSpacing.large),
        _GenreSection(ratios: snapshot.genreRatios),
        const SizedBox(height: AppSpacing.large),
        _StreakSection(streak: snapshot.streak),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selectedRange, required this.onChanged});

  final StatisticsRange selectedRange;
  final ValueChanged<StatisticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SegmentedButton<StatisticsRange>(
          segments: const [
            ButtonSegment(
              value: StatisticsRange.monthly,
              label: Text('今月'),
              icon: Icon(AppIcons.calendarMonth),
            ),
            ButtonSegment(
              value: StatisticsRange.all,
              label: Text('全期間'),
              icon: Icon(AppIcons.infinity),
            ),
          ],
          showSelectedIcon: false,
          selected: {selectedRange},
          onSelectionChanged: (value) {
            if (value.isNotEmpty) {
              onChanged(value.first);
            }
          },
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.range, required this.snapshot});

  final StatisticsRange range;
  final _StatisticsSnapshot snapshot;

  String _averageLabel() {
    if (snapshot.averageCompletionDays == null) {
      return '-';
    }
    final days = snapshot.averageCompletionDays!;
    if (days == days.roundToDouble()) {
      return '${days.toInt()}日';
    }
    return '${days.toStringAsFixed(1)}日';
  }

  String _speedLabel() {
    final speed = snapshot.averageReadingSpeed;
    if (speed == null) {
      return '-';
    }
    if (speed >= 100) {
      return '${speed.round()} ページ/時';
    }
    return '${speed.toStringAsFixed(1)} ページ/時';
  }

  String _rangeLabel() {
    return range == StatisticsRange.monthly ? '今月' : '全期間';
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
                title: '${_rangeLabel()}の読了冊数',
                value: '${snapshot.finishedBooks} 冊',
                icon: AppIcons.menuBook,
                iconColor: Colors.indigo,
              ),
            ),
            SizedBox(
              width: isWide ? constraints.maxWidth / 2 - spacing / 2 : double.infinity,
              child: _MetricCard(
                title: '${_rangeLabel()}の読書ページ',
                value: '${snapshot.pages} ページ',
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
            SizedBox(
              width: isWide ? constraints.maxWidth / 2 - spacing / 2 : double.infinity,
              child: _MetricCard(
                title: '平均読書スピード',
                value: _speedLabel(),
                icon: AppIcons.speed,
                iconColor: Colors.orange,
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

class _BestTimeSection extends StatelessWidget {
  const _BestTimeSection({
    required this.bestWeekday,
    required this.bestHour,
    required this.weekday,
    required this.hourly,
  });

  final BestReadingPeriod? bestWeekday;
  final BestReadingPeriod? bestHour;
  final List<BarValue> weekday;
  final List<BarValue> hourly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasData = weekday.any((value) => value.value > 0) ||
        hourly.any((value) => value.value > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '読書が進む曜日と時間帯',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          '読書ログから、特に進みやすい曜日と時間帯を可視化しました。',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.medium,
                runSpacing: AppSpacing.small,
                children: [
                  _BestTimeBadge(
                    icon: AppIcons.event,
                    label: '最も進む曜日',
                    value:
                        bestWeekday != null ? bestWeekday!.label : 'データなし',
                    pages: bestWeekday?.pages,
                  ),
                  _BestTimeBadge(
                    icon: AppIcons.schedule,
                    label: '最も進む時間帯',
                    value: bestHour != null ? '${bestHour!.label}' : 'データなし',
                    pages: bestHour?.pages,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.large),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 640;
                  final spacing =
                      isWide ? AppSpacing.large : AppSpacing.medium;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _BarChartCard(
                            title: '曜日別ページ数',
                            values: weekday,
                            highlight: bestWeekday?.label,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: _BarChartCard(
                            title: '時間帯別ページ数',
                            values: hourly,
                            highlight: bestHour?.label,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BarChartCard(
                        title: '曜日別ページ数',
                        values: weekday,
                        highlight: bestWeekday?.label,
                      ),
                      SizedBox(height: spacing),
                      _BarChartCard(
                        title: '時間帯別ページ数',
                        values: hourly,
                        highlight: bestHour?.label,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BestTimeBadge extends StatelessWidget {
  const _BestTimeBadge({
    required this.icon,
    required this.label,
    required this.value,
    this.pages,
  });

  final IconData icon;
  final String label;
  final String value;
  final int? pages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasValue = pages != null;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.medium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.small),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                hasValue ? '$value ・ ${pages}ページ' : value,
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.title,
    required this.values,
    this.highlight,
  });

  final String title;
  final List<BarValue> values;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasData = values.any((value) => value.value > 0);

    final maxY = values.isEmpty
        ? 10.0
        : values
            .map((e) => e.value)
            .fold<int>(0, max)
            .toDouble()
            .clamp(10, double.infinity)
            .toDouble();
    final interval = max(1, (maxY / 4).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.small),
        if (!hasData)
          const _EmptyChartMessage(
            icon: AppIcons.trendingFlat,
            message: '可視化できるデータがありません',
          )
        else
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                  horizontalInterval: interval.toDouble(),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          value.toInt().toString(),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= values.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            values[index].label,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: values.asMap().entries.map((entry) {
                  final isHighlight = highlight != null &&
                      highlight == entry.value.label;
                  final barColor = isHighlight
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.4);

                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: barColor,
                        width: 14,
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _GenreSection extends StatelessWidget {
  const _GenreSection({required this.ratios});

  final List<GenreRatio> ratios;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ジャンル別の比率',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          'タグをジャンルとして集計しています。',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: ratios.isEmpty
              ? const _EmptyChartMessage(
                  icon: AppIcons.donutSmall,
                  message: 'タグ付きの読書データがまだありません',
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 240,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: ratios.asMap().entries.map((entry) {
                            final color = colors[entry.key % colors.length];
                            return PieChartSectionData(
                              color: color.withValues(alpha: 0.9),
                              value: entry.value.percentage,
                              title:
                                  '${entry.value.percentage.toStringAsFixed(1)}%',
                              radius: 70,
                              titleStyle: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Wrap(
                      spacing: AppSpacing.medium,
                      runSpacing: AppSpacing.small,
                      children: ratios.asMap().entries.map((entry) {
                        final color = colors[entry.key % colors.length];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Text(
                              '${entry.value.name} (${entry.value.count}冊)',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StreakSection extends StatelessWidget {
  const _StreakSection({required this.streak});

  final StreakStats streak;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildStat(String label, int value, IconData icon) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.small),
            Text(
              '$value 日',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '読書の偏り',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          '連続日数やブランク期間から読書のリズムを確認できます。',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            children: [
              Row(
                children: [
                  buildStat('現在の連続日数', streak.currentStreak, AppIcons.repeat),
                  buildStat('最長連続日数', streak.longestStreak, AppIcons.leaderboard),
                  buildStat('最長ブランク', streak.longestGap, AppIcons.beachAccess),
                ],
              ),
              if (streak.currentStreak == 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.medium),
                  child: Text(
                    '今日はまだ読書記録がありません。少しだけでも読み進めてみませんか？',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
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
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final point = points[spot.x.toInt()];
                  return LineTooltipItem(
                    '${dateFormat.format(point.date)}\n${point.pages} ページ',
                    (textTheme.bodyMedium ?? const TextStyle()).copyWith(color: colorScheme.onSurface),
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
