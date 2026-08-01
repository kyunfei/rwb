import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../models/shelf/shelf_book_update_state.dart';
import '../book_data_provider.dart';
import '../storage_service.dart';
import 'shelf_chapter_diff.dart';
import 'shelf_toc_snapshot_store.dart';
import 'shelf_update_state_store.dart';

class ShelfUpdateProgress {
  final int total;
  final int completed;
  final int failed;
  final String? currentBookName;
  final bool isRunning;

  const ShelfUpdateProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.currentBookName,
    this.isRunning = false,
  });
}

class ShelfUpdateBookResult {
  final String bookUrl;
  final String bookName;
  final bool success;
  final bool hasNewChapters;
  final int newChapterCount;
  final String? error;

  const ShelfUpdateBookResult({
    required this.bookUrl,
    required this.bookName,
    required this.success,
    this.hasNewChapters = false,
    this.newChapterCount = 0,
    this.error,
  });
}

/// 书架章节更新检测（批量、可取消、单书隔离失败）
class ShelfUpdateService extends ChangeNotifier {
  ShelfUpdateService._();
  static final ShelfUpdateService instance = ShelfUpdateService._();

  static const _prefAutoCheck = 'shelf_auto_update_enabled';
  static const _prefAutoCheckHours = 'shelf_auto_update_interval_hours';
  static const _defaultConcurrency = 3;
  static const _perBookTimeout = Duration(seconds: 90);

  final Map<String, ShelfBookUpdateState> _states = {};
  final List<ShelfUpdateBookResult> _lastBatchResults = [];

  bool _isRunning = false;
  int _cancelGeneration = 0;
  Timer? _autoCheckTimer;
  bool _delayedStartDone = false;

  ShelfUpdateProgress _progress = const ShelfUpdateProgress();
  bool _autoCheckEnabled = false;
  int _autoCheckIntervalHours = 12;
  int _concurrency = _defaultConcurrency;

  bool get isRunning => _isRunning;
  ShelfUpdateProgress get progress => _progress;
  bool get autoCheckEnabled => _autoCheckEnabled;
  int get autoCheckIntervalHours => _autoCheckIntervalHours;
  int get concurrency => _concurrency;
  List<ShelfUpdateBookResult> get lastBatchResults =>
      List.unmodifiable(_lastBatchResults);

  ShelfBookUpdateState stateFor(String bookUrl) {
    return _states[bookUrl] ?? const ShelfBookUpdateState();
  }

  /// 冷启动后延迟加载状态与恢复定时器（不阻塞 main）
  Future<void> scheduleDelayedStart() async {
    if (_delayedStartDone) return;
    _delayedStartDone = true;
    await Future<void>.delayed(const Duration(seconds: 4));
    await ShelfUpdateStateStore.instance.loadAllIntoMemory();
    final all = await ShelfUpdateStateStore.instance.allStates();
    _states
      ..clear()
      ..addAll(all);
    await _loadAutoCheckPrefs();
    _scheduleAutoCheckTimer();
    notifyListeners();
  }

  Future<void> _loadAutoCheckPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCheckEnabled = prefs.getBool(_prefAutoCheck) ?? false;
    _autoCheckIntervalHours = prefs.getInt(_prefAutoCheckHours) ?? 12;
    _concurrency = prefs.getInt('shelf_update_concurrency') ?? _defaultConcurrency;
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    _autoCheckEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoCheck, enabled);
    _scheduleAutoCheckTimer();
    notifyListeners();
  }

  Future<void> setAutoCheckIntervalHours(int hours) async {
    _autoCheckIntervalHours = hours.clamp(1, 168);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefAutoCheckHours, _autoCheckIntervalHours);
    _scheduleAutoCheckTimer();
    notifyListeners();
  }

  void _scheduleAutoCheckTimer() {
    _autoCheckTimer?.cancel();
    if (!_autoCheckEnabled) return;
    final duration = Duration(hours: _autoCheckIntervalHours);
    _autoCheckTimer = Timer(duration, () {
      unawaited(_runAutoCheck());
    });
  }

  Future<void> _runAutoCheck() async {
    if (_isRunning) {
      _scheduleAutoCheckTimer();
      return;
    }
    final books = _onlineUpdatableBooks();
    if (books.isEmpty) {
      _scheduleAutoCheckTimer();
      return;
    }
    await checkBooks(books.map((b) => b.bookUrl).toList());
    _scheduleAutoCheckTimer();
  }

  List<Book> _onlineUpdatableBooks() {
    return StorageService.instance
        .getAllBooks()
        .map((e) => Book.fromJson(e))
        .where(
          (b) =>
              b.originType == BookOriginType.online &&
              b.canUpdate &&
              b.sourceUrl != null &&
              b.sourceUrl!.isNotEmpty,
        )
        .toList();
  }

  void cancelCurrentBatch() {
    _cancelGeneration++;
    notifyListeners();
  }

  Future<void> clearUpdateBadge(String bookUrl) async {
    final current = _states[bookUrl] ?? const ShelfBookUpdateState();
    final next = current.copyWith(
      hasNewChapters: false,
      newChapterCount: 0,
      clearError: true,
    );
    _states[bookUrl] = next;
    await ShelfUpdateStateStore.instance.put(bookUrl, next);
    notifyListeners();
  }

  Future<ShelfUpdateBookResult> checkBook(Book book) async {
    final now = DateTime.now();
    if (book.originType != BookOriginType.online || !book.canUpdate) {
      return ShelfUpdateBookResult(
        bookUrl: book.bookUrl,
        bookName: book.displayName,
        success: false,
        error: '本地或已禁用更新的书籍跳过',
      );
    }
    try {
      final dataProvider = createBookDataProvider(book);
      final chapters = await dataProvider
          .getChapterList(book)
          .timeout(_perBookTimeout);
      final currentEntries = ShelfChapterDiff.fromChapters(chapters);
      final previous =
          await ShelfTocSnapshotStore.instance.loadSnapshot(book.bookUrl);
      final diff = ShelfChapterDiff.compare(previous, currentEntries);

      await ShelfTocSnapshotStore.instance.saveSnapshot(
        book.bookUrl,
        currentEntries,
      );

      final readable = _lastReadableChapter(chapters);
      final updatedBook = book.copyWith(
        lastCheckTime: now,
        totalChapterNum: _countReadable(chapters),
        lastChapter: readable?.title ?? book.lastChapter,
      );
      await StorageService.instance.addToBookshelf(updatedBook.toJson());

      final state = ShelfBookUpdateState(
        hasNewChapters: diff.isFirstSnapshot ? false : diff.hasNewChapters,
        newChapterCount: diff.isFirstSnapshot ? 0 : diff.newChapterCount,
        lastCheckedAt: now,
        lastSuccessAt: now,
      );
      _states[book.bookUrl] = state;
      await ShelfUpdateStateStore.instance.put(book.bookUrl, state);

      return ShelfUpdateBookResult(
        bookUrl: book.bookUrl,
        bookName: book.displayName,
        success: true,
        hasNewChapters: diff.hasNewChapters,
        newChapterCount: diff.newChapterCount,
      );
    } on TimeoutException {
      return _failBook(book, now, '检测超时（${_perBookTimeout.inSeconds}秒）');
    } catch (e) {
      return _failBook(book, now, e.toString());
    }
  }

  Future<ShelfUpdateBookResult> _failBook(
    Book book,
    DateTime now,
    String message,
  ) async {
    final prev = _states[book.bookUrl] ?? const ShelfBookUpdateState();
    final state = prev.copyWith(
      lastError: message,
      lastCheckedAt: now,
    );
    _states[book.bookUrl] = state;
    await ShelfUpdateStateStore.instance.put(book.bookUrl, state);
    await StorageService.instance.addToBookshelf(
      book.copyWith(lastCheckTime: now).toJson(),
    );
    return ShelfUpdateBookResult(
      bookUrl: book.bookUrl,
      bookName: book.displayName,
      success: false,
      error: message,
    );
  }

  Future<List<ShelfUpdateBookResult>> checkBooks(List<String> bookUrls) async {
    if (_isRunning) {
      cancelCurrentBatch();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final generation = _cancelGeneration;
    _isRunning = true;
    _lastBatchResults.clear();

    final allData = StorageService.instance.getAllBooks();
    final byUrl = {
      for (final data in allData)
        (data['bookUrl'] as String? ?? ''): Book.fromJson(data),
    };
    final books = bookUrls.map((url) => byUrl[url]).whereType<Book>().toList();

    _progress = ShelfUpdateProgress(
      total: books.length,
      isRunning: true,
    );
    notifyListeners();

    var completed = 0;
    var failed = 0;
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        if (generation != _cancelGeneration) return;
        final i = nextIndex;
        nextIndex++;
        if (i >= books.length) return;
        final book = books[i];
        _progress = ShelfUpdateProgress(
          total: books.length,
          completed: completed,
          failed: failed,
          currentBookName: book.displayName,
          isRunning: true,
        );
        notifyListeners();
        final result = await checkBook(book);
        _lastBatchResults.add(result);
        if (result.success) {
          completed++;
        } else {
          failed++;
        }
        _progress = ShelfUpdateProgress(
          total: books.length,
          completed: completed,
          failed: failed,
          currentBookName: book.displayName,
          isRunning: true,
        );
        notifyListeners();
      }
    }

    final workers = List.generate(
      _concurrency.clamp(1, books.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    _isRunning = false;
    _progress = ShelfUpdateProgress(
      total: books.length,
      completed: completed,
      failed: failed,
      isRunning: false,
    );
    notifyListeners();
    return List.unmodifiable(_lastBatchResults);
  }

  Future<List<ShelfUpdateBookResult>> checkAllOnBookshelf() async {
    final books = _onlineUpdatableBooks();
    return checkBooks(books.map((b) => b.bookUrl).toList());
  }

  static Chapter? _lastReadableChapter(List<Chapter> chapters) {
    for (var i = chapters.length - 1; i >= 0; i--) {
      final c = chapters[i];
      if (!c.isVolume && c.url != null && c.url!.trim().isNotEmpty) {
        return c;
      }
    }
    return chapters.isNotEmpty ? chapters.last : null;
  }

  static int _countReadable(List<Chapter> chapters) {
    return chapters
        .where(
          (c) =>
              !c.isVolume && c.url != null && c.url!.trim().isNotEmpty,
        )
        .length;
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }
}
