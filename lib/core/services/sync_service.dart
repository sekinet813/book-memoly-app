import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../models/goal.dart';
import '../repositories/local_database_repository.dart';

class SupabaseSyncService {
  SupabaseSyncService({
    required SupabaseClient client,
    required LocalDatabaseRepository repository,
    Connectivity? connectivity,
  })  : _client = client,
        _repository = repository,
        _connectivity = connectivity ?? Connectivity() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((status) {
      final isConnected = status != ConnectivityResult.none;
      if (isConnected) {
        syncIfConnected();
      }
    });
  }

  static const _bookTable = 'books';
  static const _noteTable = 'notes';
  static const _actionTable = 'actions';
  static const _readingLogTable = 'reading_logs';
  static const _goalTable = 'goals';

  final SupabaseClient _client;
  final LocalDatabaseRepository _repository;
  final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _syncInProgress = false;

  String get _userId => _repository.userId;

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }

  Future<void> syncIfConnected() async {
    if (_syncInProgress) {
      return;
    }

    final hasConnection = await _hasNetworkConnection();
    if (!hasConnection) {
      return;
    }

    _syncInProgress = true;
    try {
      await Future.wait([
        _syncBooks(),
        _syncNotes(),
        _syncActions(),
        _syncReadingLogs(),
        _syncGoals(),
      ]);
    } catch (error, stackTrace) {
      debugPrint('Supabase sync failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('Supabase sync failed'),
        ),
      );
    } finally {
      _syncInProgress = false;
    }
  }

  Future<bool> _hasNetworkConnection() async {
    final status = await _connectivity.checkConnectivity();
    return status != ConnectivityResult.none;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return null;
  }

  Map<int, DateTime> _buildRemoteUpdatedAtMap(List<dynamic> rows) {
    final updatedAtMap = <int, DateTime>{};

    for (final row in rows) {
      final localId = row['local_id'];
      final updatedAt = _parseDateTime(row['updated_at']);

      if (localId is int && updatedAt != null) {
        updatedAtMap[localId] = updatedAt;
      }
    }

    return updatedAtMap;
  }

  Future<void> _syncBooks() async {
    final remoteRows = await _client
        .from(_bookTable)
        .select<List<Map<String, dynamic>>>('*')
        .eq('user_id', _userId);

    final localBooks = await _repository.getAllBooks();
    final localById = {for (final book in localBooks) book.id: book};

    await _applyRemoteBooks(remoteRows, localById);

    final mergedBooks = await _repository.getAllBooks();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedBooks.where((book) {
      final remoteUpdated = remoteUpdatedAt[book.id];
      return remoteUpdated == null ||
          book.updatedAt.toUtc().isAfter(remoteUpdated);
    }).map((book) {
      return {
        'local_id': book.id,
        'user_id': _userId,
        'google_books_id': book.googleBooksId,
        'title': book.title,
        'authors': book.authors,
        'description': book.description,
        'thumbnail_url': book.thumbnailUrl,
        'published_date': book.publishedDate,
        'page_count': book.pageCount,
        'status': book.status,
        'started_at': book.startedAt?.toUtc().toIso8601String(),
        'finished_at': book.finishedAt?.toUtc().toIso8601String(),
        'created_at': book.createdAt.toUtc().toIso8601String(),
        'updated_at': book.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_bookTable)
        .upsert(payload, onConflict: 'user_id,local_id');
  }

  Future<void> _applyRemoteBooks(
    List<dynamic> remoteRows,
    Map<int, BookRow> localById,
  ) async {
    for (final row in remoteRows) {
      final localId = row['local_id'];
      final googleBooksId = row['google_books_id'];
      final title = row['title'];
      final updatedAt = _parseDateTime(row['updated_at']);

      if (localId is! int ||
          googleBooksId is! String ||
          title is! String ||
          updatedAt == null) {
        continue;
      }

      final localUpdated = localById[localId]?.updatedAt.toUtc();
      if (localUpdated != null && !updatedAt.isAfter(localUpdated)) {
        continue;
      }

      final createdAt = _parseDateTime(row['created_at']) ?? updatedAt;

      final book = BookRow(
        id: localId,
        userId: _userId,
        googleBooksId: googleBooksId,
        title: title,
        authors: row['authors'] as String?,
        description: row['description'] as String?,
        thumbnailUrl: row['thumbnail_url'] as String?,
        publishedDate: row['published_date'] as String?,
        pageCount: _parseInt(row['page_count']),
        status: _parseInt(row['status']) ?? 0,
        startedAt: _parseDateTime(row['started_at']),
        finishedAt: _parseDateTime(row['finished_at']),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertBookFromRemote(book);
    }
  }

  Future<void> _syncNotes() async {
    final remoteRows = await _client
        .from(_noteTable)
        .select<List<Map<String, dynamic>>>('*')
        .eq('user_id', _userId);

    final localNotes = await _repository.getAllNotes();
    final localById = {for (final note in localNotes) note.id: note};

    await _applyRemoteNotes(remoteRows, localById);

    final mergedNotes = await _repository.getAllNotes();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedNotes.where((note) {
      final remoteUpdated = remoteUpdatedAt[note.id];
      return remoteUpdated == null || note.updatedAt.toUtc().isAfter(remoteUpdated);
    }).map((note) {
      return {
        'local_id': note.id,
        'user_id': _userId,
        'book_id': note.bookId,
        'content': note.content,
        'page_number': note.pageNumber,
        'created_at': note.createdAt.toUtc().toIso8601String(),
        'updated_at': note.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_noteTable)
        .upsert(payload, onConflict: 'user_id,local_id');
  }

  Future<void> _applyRemoteNotes(
    List<dynamic> remoteRows,
    Map<int, NoteRow> localById,
  ) async {
    for (final row in remoteRows) {
      final localId = row['local_id'];
      final bookId = row['book_id'];
      final content = row['content'];
      final updatedAt = _parseDateTime(row['updated_at']);

      if (localId is! int ||
          bookId is! int ||
          content is! String ||
          updatedAt == null) {
        continue;
      }

      final localUpdated = localById[localId]?.updatedAt.toUtc();
      if (localUpdated != null && !updatedAt.isAfter(localUpdated)) {
        continue;
      }

      final createdAt = _parseDateTime(row['created_at']) ?? updatedAt;

      final note = NoteRow(
        id: localId,
        userId: _userId,
        bookId: bookId,
        content: content,
        pageNumber: _parseInt(row['page_number']),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertNoteFromRemote(note);
    }
  }

  Future<void> _syncActions() async {
    final remoteRows = await _client
        .from(_actionTable)
        .select<List<Map<String, dynamic>>>('*')
        .eq('user_id', _userId);

    final localActions = await _repository.getAllActions();
    final localById = {for (final action in localActions) action.id: action};

    await _applyRemoteActions(remoteRows, localById);

    final mergedActions = await _repository.getAllActions();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedActions.where((action) {
      final remoteUpdated = remoteUpdatedAt[action.id];
      return remoteUpdated == null ||
          action.updatedAt.toUtc().isAfter(remoteUpdated);
    }).map((action) {
      return {
        'local_id': action.id,
        'user_id': _userId,
        'book_id': action.bookId,
        'note_id': action.noteId,
        'title': action.title,
        'description': action.description,
        'due_date': action.dueDate?.toUtc().toIso8601String(),
        'remind_at': action.remindAt?.toUtc().toIso8601String(),
        'status': action.status,
        'created_at': action.createdAt.toUtc().toIso8601String(),
        'updated_at': action.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_actionTable)
        .upsert(payload, onConflict: 'user_id,local_id');
  }

  Future<void> _applyRemoteActions(
    List<dynamic> remoteRows,
    Map<int, ActionRow> localById,
  ) async {
    for (final row in remoteRows) {
      final localId = row['local_id'];
      final title = row['title'];
      final updatedAt = _parseDateTime(row['updated_at']);

      if (localId is! int || title is! String || updatedAt == null) {
        continue;
      }

      final localUpdated = localById[localId]?.updatedAt.toUtc();
      if (localUpdated != null && !updatedAt.isAfter(localUpdated)) {
        continue;
      }

      final createdAt = _parseDateTime(row['created_at']) ?? updatedAt;

      final action = ActionRow(
        id: localId,
        userId: _userId,
        bookId: _parseInt(row['book_id']),
        noteId: _parseInt(row['note_id']),
        title: title,
        description: row['description'] as String?,
        dueDate: _parseDateTime(row['due_date']),
        remindAt: _parseDateTime(row['remind_at']),
        status: row['status'] as String? ?? 'pending',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertActionFromRemote(action);
    }
  }

  Future<void> _syncReadingLogs() async {
    final remoteRows = await _client
        .from(_readingLogTable)
        .select<List<Map<String, dynamic>>>('*')
        .eq('user_id', _userId);

    final localLogs = await _repository.getAllReadingLogs();
    final localById = {for (final log in localLogs) log.id: log};

    await _applyRemoteReadingLogs(remoteRows, localById);

    final mergedLogs = await _repository.getAllReadingLogs();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedLogs.where((log) {
      final remoteUpdated = remoteUpdatedAt[log.id];
      return remoteUpdated == null || log.updatedAt.toUtc().isAfter(remoteUpdated);
    }).map((log) {
      return {
        'local_id': log.id,
        'user_id': _userId,
        'book_id': log.bookId,
        'start_page': log.startPage,
        'end_page': log.endPage,
        'duration_minutes': log.durationMinutes,
        'logged_at': log.loggedAt.toUtc().toIso8601String(),
        'created_at': log.createdAt.toUtc().toIso8601String(),
        'updated_at': log.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_readingLogTable)
        .upsert(payload, onConflict: 'user_id,local_id');
  }

  Future<void> _applyRemoteReadingLogs(
    List<dynamic> remoteRows,
    Map<int, ReadingLogRow> localById,
  ) async {
    for (final row in remoteRows) {
      final localId = row['local_id'];
      final bookId = row['book_id'];
      final updatedAt = _parseDateTime(row['updated_at']);

      if (localId is! int || bookId is! int || updatedAt == null) {
        continue;
      }

      final localUpdated = localById[localId]?.updatedAt.toUtc();
      if (localUpdated != null && !updatedAt.isAfter(localUpdated)) {
        continue;
      }

      final createdAt = _parseDateTime(row['created_at']) ?? updatedAt;

      final log = ReadingLogRow(
        id: localId,
        userId: _userId,
        bookId: bookId,
        startPage: _parseInt(row['start_page']),
        endPage: _parseInt(row['end_page']),
        durationMinutes: _parseInt(row['duration_minutes']),
        loggedAt: _parseDateTime(row['logged_at']) ?? updatedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertReadingLogFromRemote(log);
    }
  }

  Future<void> _syncGoals() async {
    final remoteRows = await _client
        .from(_goalTable)
        .select<List<Map<String, dynamic>>>('*')
        .eq('user_id', _userId);

    final localGoals = await _repository.getAllGoals();
    final localById = {for (final goal in localGoals) goal.id: goal};

    await _applyRemoteGoals(remoteRows, localById);

    final mergedGoals = await _repository.getAllGoals();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedGoals.where((goal) {
      final remoteUpdated = remoteUpdatedAt[goal.id];
      return remoteUpdated == null ||
          goal.updatedAt.toUtc().isAfter(remoteUpdated);
    }).map((goal) {
      return {
        'local_id': goal.id,
        'user_id': _userId,
        'period': goal.period.storageValue,
        'year': goal.year,
        'month': goal.month,
        'target_type': goal.targetType.storageValue,
        'target_value': goal.targetValue,
        'created_at': goal.createdAt.toUtc().toIso8601String(),
        'updated_at': goal.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_goalTable)
        .upsert(payload, onConflict: 'user_id,local_id');
  }

  Future<void> _applyRemoteGoals(
    List<dynamic> remoteRows,
    Map<int, GoalRow> localById,
  ) async {
    for (final row in remoteRows) {
      final localId = row['local_id'];
      final updatedAt = _parseDateTime(row['updated_at']);
      final period = row['period'];
      final targetType = row['target_type'];
      final year = _parseInt(row['year']);

      if (localId is! int ||
          updatedAt == null ||
          period is! String ||
          targetType is! String ||
          year == null) {
        continue;
      }

      final localUpdated = localById[localId]?.updatedAt.toUtc();
      if (localUpdated != null && !updatedAt.isAfter(localUpdated)) {
        continue;
      }

      final createdAt = _parseDateTime(row['created_at']) ?? updatedAt;
      final month = _parseInt(row['month']);
      final targetValue = _parseInt(row['target_value']);

      if (targetValue == null) {
        continue;
      }

      final goal = GoalRow(
        id: localId,
        userId: _userId,
        period: GoalPeriod.fromStorage(period),
        year: year,
        month: month,
        targetType: GoalMetric.fromStorage(targetType),
        targetValue: targetValue,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertGoalFromRemote(goal);
    }
  }
}
