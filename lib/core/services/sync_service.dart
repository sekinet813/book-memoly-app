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
        _connectivity.onConnectivityChanged.listen((statusList) {
      final isConnected = !statusList.contains(ConnectivityResult.none);
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
  static const _tagTable = 'tags';
  static const _bookTagTable = 'book_tags';
  static const _noteTagTable = 'note_tags';

  final SupabaseClient _client;
  final LocalDatabaseRepository _repository;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
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
      await _syncBooks();
      await _syncNotes();
      await _syncTags();
      await _syncActions();
      await _syncReadingLogs();
      await _syncGoals();
      await _syncBookTags();
      await _syncNoteTags();
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
    final statusList = await _connectivity.checkConnectivity();
    return !statusList.contains(ConnectivityResult.none);
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
    final remoteRows = (await _client
        .from(_bookTable)
        .select('*')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

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

  Future<void> _syncTags() async {
    final remoteRows = (await _client
        .from(_tagTable)
        .select('*')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

    final localTags = await _repository.getAllTags();
    final localById = {for (final tag in localTags) tag.id: tag};

    await _applyRemoteTags(remoteRows, localById);

    final mergedTags = await _repository.getAllTags();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedTags.where((tag) {
      final remoteUpdated = remoteUpdatedAt[tag.id];
      return remoteUpdated == null ||
          tag.updatedAt.toUtc().isAfter(remoteUpdated);
    }).map((tag) {
      return {
        'local_id': tag.id,
        'user_id': _userId,
        'name': tag.name,
        'created_at': tag.createdAt.toUtc().toIso8601String(),
        'updated_at': tag.updatedAt.toUtc().toIso8601String(),
      };
    }).toList();

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_tagTable)
        .upsert(payload, onConflict: 'user_id,local_id');
  }

  Future<void> _applyRemoteTags(
    List<dynamic> remoteRows,
    Map<int, TagRow> localById,
  ) async {
    for (final row in remoteRows) {
      final localId = row['local_id'];
      final name = row['name'];
      final updatedAt = _parseDateTime(row['updated_at']);

      if (localId is! int || name is! String || updatedAt == null) {
        continue;
      }

      final localUpdated = localById[localId]?.updatedAt.toUtc();
      if (localUpdated != null && !updatedAt.isAfter(localUpdated)) {
        continue;
      }

      final createdAt = _parseDateTime(row['created_at']) ?? updatedAt;

      final tag = TagRow(
        id: localId,
        userId: _userId,
        name: name,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertTagFromRemote(tag);
    }
  }

  Future<void> _syncNotes() async {
    final remoteRows = (await _client
        .from(_noteTable)
        .select('*')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

    final localNotes = await _repository.getAllNotes();
    final localById = {for (final note in localNotes) note.id: note};

    await _applyRemoteNotes(remoteRows, localById);

    final mergedNotes = await _repository.getAllNotes();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedNotes.where((note) {
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
    final remoteRows = (await _client
        .from(_actionTable)
        .select('*')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

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
    final remoteRows = (await _client
        .from(_readingLogTable)
        .select('*')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

    final localLogs = await _repository.getAllReadingLogs();
    final localById = {for (final log in localLogs) log.id: log};

    await _applyRemoteReadingLogs(remoteRows, localById);

    final mergedLogs = await _repository.getAllReadingLogs();
    final remoteUpdatedAt = _buildRemoteUpdatedAtMap(remoteRows);

    final payload = mergedLogs.where((log) {
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
    final remoteRows = (await _client
        .from(_goalTable)
        .select('*')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

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
        'week': goal.week,
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
      final week = _parseInt(row['week']);
      final targetValue = _parseInt(row['target_value']);

      if (targetValue == null) {
        continue;
      }

      final goal = GoalRow(
        id: localId,
        userId: _userId,
        period: GoalPeriodLabel.fromStorage(period),
        year: year,
        month: month,
        week: week,
        targetType: GoalMetricLabel.fromStorage(targetType),
        targetValue: targetValue,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      await _repository.upsertGoalFromRemote(goal);
    }
  }

  Future<void> _syncBookTags() async {
    final remoteRows = (await _client.from(_bookTagTable).select('*'))
        as List<Map<String, dynamic>>;

    final bookIdMaps = await _fetchIdMaps(_bookTable);

    final remoteLinks = _mapRemoteLinks(
      remoteRows,
      'book_id',
      bookIdMaps.remoteToLocal,
    );
    final localLinks = (await _repository.getAllBookTagLinks())
        .map((row) => _TagLink(parentId: row.bookId, tagId: row.tagId))
        .toSet();

    final mergedLinks = {...remoteLinks, ...localLinks};

    await _applyTagLinksToLocal(
      mergedLinks,
      (bookId, tagIds) =>
          _repository.setTagsForBook(bookId: bookId, tagIds: tagIds),
    );

    final missingOnRemote = mergedLinks.difference(remoteLinks).toList();

    if (missingOnRemote.isEmpty) {
      return;
    }

    final payload = _buildPayload(missingOnRemote, bookIdMaps.localToRemote,
        (remoteId, link) => {'book_id': remoteId, 'tag_id': link.tagId});

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_bookTagTable)
        .upsert(payload, onConflict: 'book_id,tag_id');
  }

  Future<void> _syncNoteTags() async {
    final remoteRows = (await _client.from(_noteTagTable).select('*'))
        as List<Map<String, dynamic>>;

    final noteIdMaps = await _fetchIdMaps(_noteTable);

    final remoteLinks = _mapRemoteLinks(
      remoteRows,
      'note_id',
      noteIdMaps.remoteToLocal,
    );
    final localLinks = (await _repository.getAllNoteTagLinks())
        .map((row) => _TagLink(parentId: row.noteId, tagId: row.tagId))
        .toSet();

    final mergedLinks = {...remoteLinks, ...localLinks};

    await _applyTagLinksToLocal(
      mergedLinks,
      (noteId, tagIds) =>
          _repository.setTagsForNote(noteId: noteId, tagIds: tagIds),
    );

    final missingOnRemote = mergedLinks.difference(remoteLinks).toList();

    if (missingOnRemote.isEmpty) {
      return;
    }

    final payload = _buildPayload(missingOnRemote, noteIdMaps.localToRemote,
        (remoteId, link) => {'note_id': remoteId, 'tag_id': link.tagId});

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from(_noteTagTable)
        .upsert(payload, onConflict: 'note_id,tag_id');
  }

  Future<_IdMaps> _fetchIdMaps(String table) async {
    final rows = (await _client
        .from(table)
        .select('id,local_id')
        .eq('user_id', _userId)) as List<Map<String, dynamic>>;

    final localToRemote = <int, int>{};
    final remoteToLocal = <int, int>{};

    for (final row in rows) {
      final remoteId = _parseInt(row['id']);
      final localId = _parseInt(row['local_id']);

      if (remoteId != null && localId != null) {
        localToRemote[localId] = remoteId;
        remoteToLocal[remoteId] = localId;
      }
    }

    return _IdMaps(
      localToRemote: localToRemote,
      remoteToLocal: remoteToLocal,
    );
  }

  Set<_TagLink> _mapRemoteLinks(
    List<Map<String, dynamic>> rows,
    String key,
    Map<int, int> idMap,
  ) {
    return _buildTagLinks(rows, key)
        .map((link) => _convertParentId(link, idMap))
        .whereType<_TagLink>()
        .toSet();
  }

  List<Map<String, int>> _buildPayload(
    List<_TagLink> links,
    Map<int, int> idMap,
    Map<String, int> Function(int remoteId, _TagLink link) builder,
  ) {
    final payload = <Map<String, int>>[];

    for (final link in links) {
      final remoteId = idMap[link.parentId];

      if (remoteId != null) {
        payload.add(builder(remoteId, link));
      }
    }

    return payload;
  }

  Set<_TagLink> _buildTagLinks(List<Map<String, dynamic>> rows, String key) {
    final links = <_TagLink>{};

    for (final row in rows) {
      final parentId = _parseInt(row[key]);
      final tagId = _parseInt(row['tag_id']);

      if (parentId != null && tagId != null) {
        links.add(_TagLink(parentId: parentId, tagId: tagId));
      }
    }

    return links;
  }

  _TagLink? _convertParentId(_TagLink link, Map<int, int> idMap) {
    final parentId = idMap[link.parentId];

    if (parentId == null) {
      return null;
    }

    return _TagLink(parentId: parentId, tagId: link.tagId);
  }

  Future<void> _applyTagLinksToLocal(
    Set<_TagLink> links,
    Future<void> Function(int id, List<int> tagIds) setter,
  ) async {
    final byParent = <int, Set<int>>{};

    for (final link in links) {
      byParent.putIfAbsent(link.parentId, () => <int>{}).add(link.tagId);
    }

    for (final entry in byParent.entries) {
      await setter(entry.key, entry.value.toList());
    }
  }
}

class _IdMaps {
  const _IdMaps({
    required this.localToRemote,
    required this.remoteToLocal,
  });

  final Map<int, int> localToRemote;
  final Map<int, int> remoteToLocal;
}

class _TagLink {
  const _TagLink({required this.parentId, required this.tagId});

  final int parentId;
  final int tagId;

  @override
  bool operator ==(Object other) {
    return other is _TagLink &&
        other.parentId == parentId &&
        other.tagId == tagId;
  }

  @override
  int get hashCode => Object.hash(parentId, tagId);
}
