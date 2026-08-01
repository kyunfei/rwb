import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../models/shelf/shelf_download_task.dart';
import '../book_data_provider.dart';
import '../chapter_cache_service.dart';
import '../storage_service.dart';
import 'shelf_download_queue_persistence.dart';

/// 离线下载任务队列：暂停/继续/取消、断点续传、并发下载
class ShelfDownloadQueueService extends ChangeNotifier {
  ShelfDownloadQueueService._();
  static final ShelfDownloadQueueService instance =
      ShelfDownloadQueueService._();

  static const _prefConcurrency = 'shelf_download_concurrency';
  static const _prefAutoResume = 'shelf_download_auto_resume';

  final List<ShelfDownloadTask> _tasks = [];
  int _concurrency = 2;
  bool _workerRunning = false;
  bool _workerStopRequested = false;
  bool _delayedStartDone = false;
  String? _activeTaskId;

  List<ShelfDownloadTask> get tasks => List.unmodifiable(_tasks);
  int get concurrency => _concurrency;
  String? get activeTaskId => _activeTaskId;

  ShelfDownloadTask? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<ShelfDownloadTask> tasksForBook(String bookUrl) {
    return _tasks.where((t) => t.bookUrl == bookUrl).toList();
  }

  Future<void> scheduleDelayedStart() async {
    if (_delayedStartDone) return;
    _delayedStartDone = true;
    await Future<void>.delayed(const Duration(seconds: 5));
    await _loadPrefs();
    final snapshot = await ShelfDownloadQueuePersistence.instance.load();
    _concurrency = snapshot.concurrency;
    _tasks
      ..clear()
      ..addAll(
        snapshot.tasks.map(
          (t) => t.copyWith(
            status: ShelfDownloadQueueStateMachine.normalizeOnColdStart(
              t.status,
            ),
            updatedAt: DateTime.now(),
          ),
        ),
      );
    await _persist();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final autoResume = prefs.getBool(_prefAutoResume) ?? true;
    if (autoResume) {
      for (final task in _tasks) {
        if (task.status == ShelfDownloadTaskStatus.paused &&
            task.completedInRange < task.totalInRange) {
          unawaited(resumeTask(task.id));
          break;
        }
      }
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _concurrency = prefs.getInt(_prefConcurrency) ?? 2;
  }

  Future<void> setConcurrency(int value) async {
    _concurrency = value.clamp(1, 6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefConcurrency, _concurrency);
    notifyListeners();
  }

  Future<void> _persist() async {
    await ShelfDownloadQueuePersistence.instance.save(
      ShelfDownloadQueueSnapshot(
        concurrency: _concurrency,
        tasks: _tasks,
      ),
    );
  }

  String _newTaskId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

  Future<String?> enqueueTask({
    required Book book,
    required List<Chapter> chapters,
    required ShelfDownloadRangeMode rangeMode,
    int? customStart,
    int? customEnd,
    int currentChapterIndex = 0,
  }) async {
    if (book.originType != BookOriginType.online) {
      return null;
    }
    if (book.mediaType != MediaType.novel) {
      return null;
    }

    final refs = chapters
        .map(
          (c) => ShelfDownloadChapterRef(
            index: c.index,
            title: c.title,
            url: c.url,
            isVolume: c.isVolume,
          ),
        )
        .toList();

    final maxIndex = refs.isEmpty
        ? 0
        : refs.map((e) => e.index).reduce((a, b) => a > b ? a : b);
    final minIndex = refs.isEmpty
        ? 0
        : refs.map((e) => e.index).reduce((a, b) => a < b ? a : b);

    late int start;
    late int end;
    switch (rangeMode) {
      case ShelfDownloadRangeMode.all:
        start = minIndex;
        end = maxIndex;
        break;
      case ShelfDownloadRangeMode.fromCurrent:
        start = currentChapterIndex;
        end = maxIndex;
        break;
      case ShelfDownloadRangeMode.custom:
        start = (customStart ?? minIndex).clamp(minIndex, maxIndex);
        end = (customEnd ?? maxIndex).clamp(minIndex, maxIndex);
        if (start > end) {
          final tmp = start;
          start = end;
          end = tmp;
        }
        break;
    }

    final now = DateTime.now();
    final task = ShelfDownloadTask(
      id: _newTaskId(),
      bookUrl: book.bookUrl,
      bookName: book.displayName,
      rangeMode: rangeMode,
      rangeStartIndex: start,
      rangeEndIndex: end,
      chapters: refs,
      createdAt: now,
      updatedAt: now,
      status: ShelfDownloadTaskStatus.pending,
    );
    _tasks.insert(0, task);
    await _persist();
    notifyListeners();
    unawaited(_ensureWorker());
    return task.id;
  }

  Future<void> pauseTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final task = _tasks[index];
    if (!ShelfDownloadQueueStateMachine.canTransition(
      task.status,
      ShelfDownloadTaskStatus.paused,
    )) {
      return;
    }
    _tasks[index] = task.copyWith(
      status: ShelfDownloadTaskStatus.paused,
      updatedAt: DateTime.now(),
    );
    if (_activeTaskId == taskId) {
      _workerStopRequested = true;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> resumeTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final task = _tasks[index];
    if (task.status == ShelfDownloadTaskStatus.completed ||
        task.status == ShelfDownloadTaskStatus.cancelled) {
      return;
    }
    _tasks[index] = task.copyWith(
      status: ShelfDownloadTaskStatus.pending,
      updatedAt: DateTime.now(),
      clearLastError: true,
    );
    await _persist();
    notifyListeners();
    unawaited(_ensureWorker());
  }

  Future<void> cancelTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    if (_activeTaskId == taskId) {
      _workerStopRequested = true;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: ShelfDownloadTaskStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _persist();
    notifyListeners();
  }

  Future<void> retryFailedChapters(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index < 0) return;
    final task = _tasks[index];
    if (task.failedChapters.isEmpty) return;
    final failedIndices = task.failedChapters.map((e) => e.index).toSet();
    final completed = Set<int>.from(task.completedIndices)..removeAll(failedIndices);
    _tasks[index] = task.copyWith(
      completedIndices: completed,
      failedChapters: [],
      status: ShelfDownloadTaskStatus.pending,
      updatedAt: DateTime.now(),
      clearLastError: true,
    );
    await _persist();
    notifyListeners();
    unawaited(_ensureWorker());
  }

  Future<void> _ensureWorker() async {
    if (_workerRunning) return;
    _workerRunning = true;
    try {
      while (true) {
        _workerStopRequested = false;
        final nextIndex = _tasks.indexWhere(
          (t) =>
              t.status == ShelfDownloadTaskStatus.pending ||
              (t.status == ShelfDownloadTaskStatus.running &&
                  t.completedInRange < t.totalInRange),
        );
        if (nextIndex < 0) break;

        var task = _tasks[nextIndex];
        if (task.status == ShelfDownloadTaskStatus.pending) {
          task = task.copyWith(
            status: ShelfDownloadTaskStatus.running,
            updatedAt: DateTime.now(),
          );
          _tasks[nextIndex] = task;
          await _persist();
          notifyListeners();
        }

        _activeTaskId = task.id;
        await _runTask(task);
        _activeTaskId = null;

        if (_workerStopRequested) {
          break;
        }
      }
    } finally {
      _workerRunning = false;
      notifyListeners();
    }
  }

  Future<void> _runTask(ShelfDownloadTask task) async {
    final bookData = StorageService.instance.getBook(task.bookUrl);
    if (bookData == null) {
      _updateTask(
        task.id,
        task.copyWith(
          status: ShelfDownloadTaskStatus.failed,
          lastError: '书籍不存在',
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    final book = Book.fromJson(bookData);
    final dataProvider = createBookDataProvider(book);
    final allChapters = task.chapters
        .map(
          (ref) => Chapter(
            id: '${task.bookUrl}_${ref.index}',
            bookId: task.bookUrl,
            title: ref.title,
            index: ref.index,
            url: ref.url,
            isVolume: ref.isVolume,
          ),
        )
        .toList();

    final pending =
        ShelfDownloadQueueStateMachine.pendingChapterIndices(task);
    var completed = Set<int>.from(task.completedIndices);
    var failed = List<ShelfDownloadFailedChapter>.from(task.failedChapters);

    for (var i = 0; i < pending.length; i += _concurrency) {
      if (_workerStopRequested) {
        _updateTask(
          task.id,
          (taskById(task.id) ?? task).copyWith(
            status: ShelfDownloadTaskStatus.paused,
            updatedAt: DateTime.now(),
          ),
        );
        return;
      }
      final batch = pending.skip(i).take(_concurrency).toList();
      await Future.wait(
        batch.map((chapterIndex) async {
          if (_workerStopRequested) return;
          final ref = task.chapters.firstWhere((c) => c.index == chapterIndex);
          final chapter = Chapter(
            id: '${task.bookUrl}_$chapterIndex',
            bookId: task.bookUrl,
            title: ref.title,
            index: ref.index,
            url: ref.url,
            isVolume: ref.isVolume,
          );
          try {
            final cached = await ChapterCacheService.instance
                .hasChapterCache(book, chapter);
            if (cached) {
              completed.add(chapterIndex);
              failed.removeWhere((e) => e.index == chapterIndex);
              task = _mergeTaskProgress(task, completed, failed);
              await _persistTask(task);
              notifyListeners();
              return;
            }
            final content = await dataProvider
                .getContent(book, chapter, allChapters: allChapters)
                .timeout(const Duration(seconds: 120));
            if (content == null || content.isEmpty) {
              throw StateError('正文为空');
            }
            await ChapterCacheService.instance.saveChapterContent(
              book,
              chapter,
              content,
            );
            completed.add(chapterIndex);
            failed.removeWhere((e) => e.index == chapterIndex);
          } catch (e) {
            failed.removeWhere((f) => f.index == chapterIndex);
            failed.add(
              ShelfDownloadFailedChapter(
                index: chapterIndex,
                error: e.toString(),
              ),
            );
          }
          task = _mergeTaskProgress(task, completed, failed);
          await _persistTask(task);
          notifyListeners();
        }),
      );
    }

    final refreshed = taskById(task.id) ?? task;
    final done = refreshed.completedInRange >= refreshed.totalInRange &&
        refreshed.totalInRange > 0;
    final status = done
        ? ShelfDownloadTaskStatus.completed
        : (refreshed.failedChapters.isNotEmpty &&
                refreshed.completedInRange < refreshed.totalInRange
            ? ShelfDownloadTaskStatus.paused
            : ShelfDownloadTaskStatus.paused);

    _updateTask(
      refreshed.id,
      refreshed.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      ),
    );
  }

  ShelfDownloadTask _mergeTaskProgress(
    ShelfDownloadTask task,
    Set<int> completed,
    List<ShelfDownloadFailedChapter> failed,
  ) {
    return task.copyWith(
      completedIndices: completed,
      failedChapters: failed,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _persistTask(ShelfDownloadTask task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
    }
    await _persist();
  }

  void _updateTask(String id, ShelfDownloadTask task) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index >= 0) {
      _tasks[index] = task;
      unawaited(_persist());
      notifyListeners();
    }
  }
}
