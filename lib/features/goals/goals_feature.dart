import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/book.dart';
import '../../core/models/goal.dart';
import '../../core/providers/database_providers.dart';
import '../../core/repositories/local_database_repository.dart';
import '../../core/theme/tokens/spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../shared/constants/app_icons.dart';

final goalsNotifierProvider =
    StateNotifierProvider<GoalsNotifier, GoalsState>((ref) {
  final repository = ref.read(localDatabaseRepositoryProvider);
  return GoalsNotifier(repository)..load();
});

class GoalsState {
  const GoalsState({
    this.weeklyGoal,
    this.monthlyGoal,
    this.yearlyGoal,
    this.weeklyPagesRead = 0,
    this.monthlyPagesRead = 0,
    this.yearlyPagesRead = 0,
    this.weeklyFinishedBooks = 0,
    this.monthlyFinishedBooks = 0,
    this.yearlyFinishedBooks = 0,
    this.isLoading = true,
    this.error,
  });

  final GoalRow? weeklyGoal;
  final GoalRow? monthlyGoal;
  final GoalRow? yearlyGoal;
  final int weeklyPagesRead;
  final int monthlyPagesRead;
  final int yearlyPagesRead;
  final int weeklyFinishedBooks;
  final int monthlyFinishedBooks;
  final int yearlyFinishedBooks;
  final bool isLoading;
  final String? error;

  GoalsState copyWith({
    GoalRow? weeklyGoal,
    GoalRow? monthlyGoal,
    GoalRow? yearlyGoal,
    int? weeklyPagesRead,
    int? monthlyPagesRead,
    int? yearlyPagesRead,
    int? weeklyFinishedBooks,
    int? monthlyFinishedBooks,
    int? yearlyFinishedBooks,
    bool? isLoading,
    String? error,
  }) {
    return GoalsState(
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      monthlyGoal: monthlyGoal ?? this.monthlyGoal,
      yearlyGoal: yearlyGoal ?? this.yearlyGoal,
      weeklyPagesRead: weeklyPagesRead ?? this.weeklyPagesRead,
      monthlyPagesRead: monthlyPagesRead ?? this.monthlyPagesRead,
      yearlyPagesRead: yearlyPagesRead ?? this.yearlyPagesRead,
      weeklyFinishedBooks: weeklyFinishedBooks ?? this.weeklyFinishedBooks,
      monthlyFinishedBooks: monthlyFinishedBooks ?? this.monthlyFinishedBooks,
      yearlyFinishedBooks: yearlyFinishedBooks ?? this.yearlyFinishedBooks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get weeklyProgressValue {
    final goal = weeklyGoal;
    if (goal == null) {
      return weeklyPagesRead;
    }
    return goal.targetType == GoalMetric.pages
        ? weeklyPagesRead
        : weeklyFinishedBooks;
  }

  int get monthlyProgressValue {
    final goal = monthlyGoal;
    if (goal == null) {
      return monthlyPagesRead;
    }
    return goal.targetType == GoalMetric.pages
        ? monthlyPagesRead
        : monthlyFinishedBooks;
  }

  int get yearlyProgressValue {
    final goal = yearlyGoal;
    if (goal == null) {
      return yearlyFinishedBooks;
    }
    return goal.targetType == GoalMetric.pages
        ? yearlyPagesRead
        : yearlyFinishedBooks;
  }
}

class GoalsNotifier extends StateNotifier<GoalsState> {
  GoalsNotifier(this._repository) : super(const GoalsState());

  final LocalDatabaseRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final books = await _repository.getAllBooks();
      final logs = await _repository.getAllReadingLogs();
      final weeklyGoal = await _repository.getWeeklyGoal(now);
      final monthlyGoal = await _repository.getMonthlyGoal(now);
      final yearlyGoal = await _repository.getYearlyGoal(now.year);

      final weeklyPages = _pagesForWeek(logs, now);
      final monthlyPages = _pagesForMonth(logs, now);
      final yearlyPages = _pagesForYear(logs, now.year);
      final weeklyFinished = _finishedBooksForWeek(books, now);
      final monthlyFinished = _finishedBooksForMonth(books, now);
      final yearlyFinished = _finishedBooksForYear(books, now.year);

      state = state.copyWith(
        weeklyGoal: weeklyGoal,
        monthlyGoal: monthlyGoal,
        yearlyGoal: yearlyGoal,
        weeklyPagesRead: weeklyPages,
        monthlyPagesRead: monthlyPages,
        yearlyPagesRead: yearlyPages,
        weeklyFinishedBooks: weeklyFinished,
        monthlyFinishedBooks: monthlyFinished,
        yearlyFinishedBooks: yearlyFinished,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> saveMonthlyGoal({
    required GoalMetric metric,
    required int targetValue,
  }) async {
    final now = DateTime.now();
    await _repository.upsertGoal(
      period: GoalPeriod.monthly,
      targetType: metric,
      targetValue: targetValue,
      year: now.year,
      month: now.month,
    );
    await load();
  }

  Future<void> saveWeeklyGoal({
    required GoalMetric metric,
    required int targetValue,
  }) async {
    final now = DateTime.now();
    await _repository.upsertGoal(
      period: GoalPeriod.weekly,
      targetType: metric,
      targetValue: targetValue,
      year: now.year,
      week: weekOfYear(now),
    );
    await load();
  }

  Future<void> saveYearlyGoal({
    required GoalMetric metric,
    required int targetValue,
  }) async {
    final now = DateTime.now();
    await _repository.upsertGoal(
      period: GoalPeriod.yearly,
      targetType: metric,
      targetValue: targetValue,
      year: now.year,
    );
    await load();
  }

  int _pagesForMonth(List<ReadingLogRow> logs, DateTime date) {
    return logs
        .where((log) => log.loggedAt.year == date.year &&
            log.loggedAt.month == date.month)
        .fold(0, (sum, log) => sum + _pagesRead(log));
  }

  int _pagesForWeek(List<ReadingLogRow> logs, DateTime date) {
    final start = startOfWeek(date);
    final end = start.add(const Duration(days: 7));

    return logs
        .where(
          (log) => _isWithinRange(log.loggedAt, start, end),
        )
        .fold(0, (sum, log) => sum + _pagesRead(log));
  }

  int _pagesForYear(List<ReadingLogRow> logs, int year) {
    return logs
        .where((log) => log.loggedAt.year == year)
        .fold(0, (sum, log) => sum + _pagesRead(log));
  }

  int _finishedBooksForWeek(List<BookRow> books, DateTime date) {
    final start = startOfWeek(date);
    final end = start.add(const Duration(days: 7));

    return books.where((book) {
      if (book.finishedAt == null) return false;
      final status = bookStatusFromDbValue(book.status);
      return status == BookStatus.finished &&
          _isWithinRange(book.finishedAt!, start, end);
    }).length;
  }

  int _finishedBooksForMonth(List<BookRow> books, DateTime date) {
    return books.where((book) {
      if (book.finishedAt == null) return false;
      final status = bookStatusFromDbValue(book.status);
      return status == BookStatus.finished &&
          book.finishedAt!.year == date.year &&
          book.finishedAt!.month == date.month;
    }).length;
  }

  int _finishedBooksForYear(List<BookRow> books, int year) {
    return books.where((book) {
      if (book.finishedAt == null) return false;
      final status = bookStatusFromDbValue(book.status);
      return status == BookStatus.finished && book.finishedAt!.year == year;
    }).length;
  }

  int _pagesRead(ReadingLogRow log) {
    final start = log.startPage ?? 0;
    final end = log.endPage ?? 0;
    return max(0, end - start);
  }

  bool _isWithinRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && date.isBefore(end);
  }
}

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  late final TextEditingController _weeklyController;
  late final TextEditingController _monthlyController;
  late final TextEditingController _yearlyController;
  GoalMetric _weeklyMetric = GoalMetric.pages;
  GoalMetric _monthlyMetric = GoalMetric.pages;
  GoalMetric _yearlyMetric = GoalMetric.books;

  @override
  void initState() {
    super.initState();
    _weeklyController = TextEditingController();
    _monthlyController = TextEditingController();
    _yearlyController = TextEditingController();
  }

  @override
  void dispose() {
    _weeklyController.dispose();
    _monthlyController.dispose();
    _yearlyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(goalsNotifierProvider);
    _syncControllers(state);

    return AppPage(
      title: '読書目標',
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      scrollable: true,
      actions: [
        IconButton(
          tooltip: '再読み込み',
          onPressed: () =>
              ref.read(goalsNotifierProvider.notifier).load(),
          icon: const Icon(AppIcons.refresh),
        ),
      ],
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: state.isLoading
            ? const LoadingIndicator()
            : state.error != null
                ? _ErrorMessage(message: state.error!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '週間・月間・年間の目標を設定して、今の進捗をひと目で確認しましょう。',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      _GoalSection(
                        title: '今週の目標',
                        icon: AppIcons.calendarViewWeek,
                        goal: state.weeklyGoal,
                        progress: state.weeklyProgressValue,
                        controller: _weeklyController,
                        selectedMetric: _weeklyMetric,
                        onMetricChanged: (metric) {
                          setState(() => _weeklyMetric = metric);
                        },
                        onSave: (value) async {
                          await ref
                              .read(goalsNotifierProvider.notifier)
                              .saveWeeklyGoal(
                                metric: _weeklyMetric,
                                targetValue: value,
                              );
                        },
                      ),
                      const SizedBox(height: AppSpacing.large),
                      _GoalSection(
                        title: '今月の目標',
                        icon: AppIcons.speed,
                        goal: state.monthlyGoal,
                        progress: state.monthlyProgressValue,
                        controller: _monthlyController,
                        selectedMetric: _monthlyMetric,
                        onMetricChanged: (metric) {
                          setState(() => _monthlyMetric = metric);
                        },
                        onSave: (value) async {
                          await ref
                              .read(goalsNotifierProvider.notifier)
                              .saveMonthlyGoal(
                                metric: _monthlyMetric,
                                targetValue: value,
                              );
                        },
                      ),
                      const SizedBox(height: AppSpacing.large),
                      _GoalSection(
                        title: '今年の目標',
                        icon: AppIcons.menuBook,
                        goal: state.yearlyGoal,
                        progress: state.yearlyProgressValue,
                        controller: _yearlyController,
                        selectedMetric: _yearlyMetric,
                        onMetricChanged: (metric) {
                          setState(() => _yearlyMetric = metric);
                        },
                        onSave: (value) async {
                          await ref
                              .read(goalsNotifierProvider.notifier)
                              .saveYearlyGoal(
                                metric: _yearlyMetric,
                                targetValue: value,
                              );
                        },
                      ),
                    ],
                  ),
      ),
    );
  }

  void _syncControllers(GoalsState state) {
    final weeklyGoal = state.weeklyGoal;
    if (weeklyGoal != null) {
      final value = weeklyGoal.targetValue.toString();
      if (_weeklyController.text != value) {
        _weeklyController.text = value;
      }
      if (_weeklyMetric != weeklyGoal.targetType) {
        _weeklyMetric = weeklyGoal.targetType;
      }
    }

    final monthlyGoal = state.monthlyGoal;
    if (monthlyGoal != null) {
      final value = monthlyGoal.targetValue.toString();
      if (_monthlyController.text != value) {
        _monthlyController.text = value;
      }
      if (_monthlyMetric != monthlyGoal.targetType) {
        _monthlyMetric = monthlyGoal.targetType;
      }
    }

    final yearlyGoal = state.yearlyGoal;
    if (yearlyGoal != null) {
      final value = yearlyGoal.targetValue.toString();
      if (_yearlyController.text != value) {
        _yearlyController.text = value;
      }
      if (_yearlyMetric != yearlyGoal.targetType) {
        _yearlyMetric = yearlyGoal.targetType;
      }
    }
  }
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.title,
    required this.icon,
    required this.goal,
    required this.progress,
    required this.controller,
    required this.selectedMetric,
    required this.onMetricChanged,
    required this.onSave,
  });

  final String title;
  final IconData icon;
  final GoalRow? goal;
  final int progress;
  final TextEditingController controller;
  final GoalMetric selectedMetric;
  final ValueChanged<GoalMetric> onMetricChanged;
  final ValueChanged<int> onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final target = goal?.targetValue ?? 0;
    final metric = goal?.targetType ?? selectedMetric;
    final unit = metric.unitSuffix;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primaryContainer,
                child:
                    Icon(icon, color: colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                goal == null ? '未設定' : '${goal!.targetValue} $unit',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          _GoalProgressBar(
            progress: progress,
            target: target,
            unit: unit,
          ),
          const SizedBox(height: AppSpacing.medium),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '${metric.label}の目標値',
                    prefixIcon: const Icon(AppIcons.edit),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              DropdownButton<GoalMetric>(
                value: metric,
                items: GoalMetric.values
                    .map(
                      (goalMetric) => DropdownMenuItem(
                        value: goalMetric,
                        child: Text(goalMetric.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onMetricChanged(value);
                  }
                },
              ),
              const SizedBox(width: AppSpacing.small),
              FilledButton.icon(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('正しい目標値を入力してください')),
                    );
                    return;
                  }
                  onSave(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('目標を保存しました')),
                  );
                },
                icon: const Icon(AppIcons.check),
                label: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalProgressBar extends StatelessWidget {
  const _GoalProgressBar({
    required this.progress,
    required this.target,
    required this.unit,
  });

  final int progress;
  final int target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratio = target == 0 ? 0.0 : (progress / target).clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '達成状況',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              target == 0
                  ? '$progress $unit'
                  : '$progress / $target $unit',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor:
                colorScheme.surfaceVariant.withValues(alpha: 0.5),
            valueColor:
                AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppSpacing.small),
            Text(
              '目標情報の取得に失敗しました',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
