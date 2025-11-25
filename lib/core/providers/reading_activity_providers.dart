import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/database_providers.dart';

final todayReadingSessionsProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(localDatabaseRepositoryProvider);
  final logs = await repository.getReadingLogs();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return logs
      .where((log) {
        final loggedAt = log.loggedAt;
        final logDate = DateTime(loggedAt.year, loggedAt.month, loggedAt.day);
        return logDate == today;
      })
      .length;
});
