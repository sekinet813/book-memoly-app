import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<Map<int, DateTime>> _fetchRemoteUpdatedAt(String table) async {
    final response = await _client
        .from(table)
        .select('local_id, updated_at')
        .eq('user_id', _userId);

    final updatedAtMap = <int, DateTime>{};
    for (final item in response) {
      final localId = item['local_id'];
      final updatedAt = item['updated_at'];
      if (localId is int && updatedAt is String) {
        final parsed = DateTime.tryParse(updatedAt);
        if (parsed != null) {
          updatedAtMap[localId] = parsed.toUtc();
        }
      }
    }
    return updatedAtMap;
  }

  Future<void> _syncBooks() async {
    final localBooks = await _repository.getAllBooks();
    final remoteUpdatedAt = await _fetchRemoteUpdatedAt(_bookTable);

    final payload = localBooks.where((book) {
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

  Future<void> _syncNotes() async {
    final notes = await _repository.getAllNotes();
    final remoteUpdatedAt = await _fetchRemoteUpdatedAt(_noteTable);

    final payload = notes.where((note) {
      final remoteUpdated = remoteUpdatedAt[note.id];
      return remoteUpdated == null ||
          note.updatedAt.toUtc().isAfter(remoteUpdated);
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

  Future<void> _syncActions() async {
    final actions = await _repository.getAllActions();
    final remoteUpdatedAt = await _fetchRemoteUpdatedAt(_actionTable);

    final payload = actions.where((action) {
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

  Future<void> _syncReadingLogs() async {
    final logs = await _repository.getAllReadingLogs();
    final remoteUpdatedAt = await _fetchRemoteUpdatedAt(_readingLogTable);

    final payload = logs.where((log) {
      final remoteUpdated = remoteUpdatedAt[log.id];
      return remoteUpdated == null ||
          log.updatedAt.toUtc().isAfter(remoteUpdated);
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
}
