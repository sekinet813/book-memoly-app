enum GoalPeriod { weekly, monthly, yearly }

enum GoalMetric { pages, books }

extension GoalPeriodLabel on GoalPeriod {
  String get label {
    switch (this) {
      case GoalPeriod.weekly:
        return '週間目標';
      case GoalPeriod.monthly:
        return '月間目標';
      case GoalPeriod.yearly:
        return '年間目標';
    }
  }

  String get storageValue => toString().split('.').last;

  static GoalPeriod fromStorage(String value) {
    return GoalPeriod.values.firstWhere(
      (period) => period.storageValue == value,
      orElse: () => GoalPeriod.monthly,
    );
  }
}

extension GoalMetricLabel on GoalMetric {
  String get label {
    switch (this) {
      case GoalMetric.pages:
        return 'ページ数';
      case GoalMetric.books:
        return '冊数';
    }
  }

  String get unitSuffix {
    switch (this) {
      case GoalMetric.pages:
        return 'ページ';
      case GoalMetric.books:
        return '冊';
    }
  }

  String get storageValue => toString().split('.').last;

  static GoalMetric fromStorage(String value) {
    return GoalMetric.values.firstWhere(
      (metric) => metric.storageValue == value,
      orElse: () => GoalMetric.pages,
    );
  }
}

DateTime startOfWeek(DateTime date) {
  return DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: date.weekday - 1));
}

int weekOfYear(DateTime date) {
  final start = startOfWeek(date);
  final startOfFirstWeek = startOfWeek(DateTime(date.year, 1, 1));
  final diffDays = start.difference(startOfFirstWeek).inDays;
  return (diffDays ~/ 7) + 1;
}
