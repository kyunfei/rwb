import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_source.dart';
import '../models/book_search_exception.dart';
import '../models/search_source_status.dart';
import '../services/search/search_aggregator.dart';
import '../services/source_engine/source_engine.dart';
import '../services/storage_service.dart';

typedef BookSourceSearcher = Future<List<Map<String, dynamic>>> Function(
  BookSource source,
  String keyword,
);

/// 多源全局搜索：可控并发、可取消、单源失败隔离、流式归并去重排序。
class SearchProvider extends ChangeNotifier {
  SearchProvider({
    int maxConcurrentSearches = 12,
    this._perSourceTimeout = const Duration(seconds: 20),
    BookSourceSearcher? searcher,
    List<BookSource> initialSources = const [],
  })  : _maxConcurrentSearches =
            maxConcurrentSearches.clamp(1, 64),
        _searcher = searcher ?? _searchSource,
        _bookSources = List.of(initialSources),
        _selectedSourceUrls =
            initialSources.map((source) => source.bookSourceUrl).toSet();

  static const String _prefsConcurrentKey = 'searchMaxConcurrent';
  static const String _prefsSelectedSourcesKey = 'searchSelectedSourceUrls';
  static const int defaultMaxConcurrent = 12;

  /// 首次使用时自动选中的书源数量上限。
  ///
  /// 从公开源池导入动辄几百个源，全选会让每次搜索都拖着一大堆死源等超时；
  /// 只选头部若干个，按质量排序（见 [pickDefaultSourceUrls]）。用户仍可自行全选。
  static const int defaultAutoSelectLimit = 50;

  int _maxConcurrentSearches;
  final Duration _perSourceTimeout;
  final BookSourceSearcher _searcher;

  List<BookSource> _bookSources;
  Set<String> _selectedSourceUrls;

  /// 进入「只搜某一个源」的路由前的多源选择，返回时用来还原。
  Set<String>? _selectionBeforeSingleSourceRoute;
  bool _selectionRestored = false;
  final SearchAggregator _aggregator = SearchAggregator();
  final Map<String, SourceSearchStatus> _sourceStatuses = {};
  bool _isLoading = false;
  bool _singleSourceRouteActive = false;
  String? _error;
  List<String> _searchHistory = [];
  String _currentKeyword = '';
  int _searchGeneration = 0;
  int _finishedSourceCount = 0;
  int _totalSourceCount = 0;

  List<BookSource> get bookSources => _bookSources;
  Set<String> get selectedSourceUrls => _selectedSourceUrls;
  List<BookSource> get selectedSources => _bookSources
      .where((source) => _selectedSourceUrls.contains(source.bookSourceUrl))
      .toList();
  List<Map<String, dynamic>> get searchResults => _aggregator.results;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get searchHistory => _searchHistory;
  String get currentKeyword => _currentKeyword;
  int get maxConcurrentSearches => _maxConcurrentSearches;
  int get finishedSourceCount => _finishedSourceCount;
  int get totalSourceCount => _totalSourceCount;

  List<SourceSearchStatus> get sourceStatuses =>
      _sourceStatuses.values.toList(growable: false);

  int get failedSourceCount => _sourceStatuses.values
      .where((s) => s.phase == SourceSearchPhase.failed)
      .length;

  int get noResultSourceCount => _sourceStatuses.values
      .where((s) => s.phase == SourceSearchPhase.noResults)
      .length;

  int get successSourceCount => _sourceStatuses.values
      .where((s) => s.phase == SourceSearchPhase.success)
      .length;

  /// 本轮结束后给用户看的摘要（失败原因归类）。
  String? get searchSummary {
    if (_isLoading || _currentKeyword.isEmpty) return null;
    if (_totalSourceCount == 0) return null;
    final parts = <String>[
      '完成 $_finishedSourceCount/$_totalSourceCount 源',
      '命中 $successSourceCount',
      if (noResultSourceCount > 0) '无结果 $noResultSourceCount',
      if (failedSourceCount > 0) '失败 $failedSourceCount',
    ];
    return parts.join(' · ');
  }

  Future<void> loadBookSources() async {
    // 必须先还原用户上次的选择，再决定是否套用默认值：否则下面「为空就填默认」
    // 会先把默认值写回 prefs，把用户手选的结果冲掉。
    await _restoreSelectedSources();
    final sourcesData = StorageService.instance.getAllBookSources();
    _bookSources = [];
    for (final data in sourcesData) {
      try {
        _bookSources.add(BookSource.fromJson(data));
      } catch (e) {
        debugPrint('跳过无效书源 ${data['bookSourceUrl'] ?? ''}: $e');
      }
    }

    _bookSources = _bookSources
        .where(
          (source) =>
              source.enabled &&
              source.searchUrl != null &&
              source.searchUrl!.isNotEmpty,
        )
        .toList();

    // 丢掉已删除书源的残留选中项，否则选中数会虚高、且永远搜不到那些源
    final available =
        _bookSources.map((source) => source.bookSourceUrl).toSet();
    _selectedSourceUrls.removeWhere((url) => !available.contains(url));

    if (_selectedSourceUrls.isEmpty && _bookSources.isNotEmpty) {
      _selectedSourceUrls = pickDefaultSourceUrls(_bookSources).toSet();
      await _saveSelectedSources();
    }

    notifyListeners();
  }

  /// 挑默认选中的书源：按质量降序取前 [limit] 个。
  ///
  /// 排序依据 weight（书源自带的质量分，阅读/Legado 会随使用情况维护它）、
  /// respondTime（越小越快）、customOrder（用户置顶）。
  /// 原先是 `take(5)`——按存储顺序取前五个，等于随机；导入几百个源后
  /// 极易全落在死源上，表现为「搜什么都没结果」。
  static List<String> pickDefaultSourceUrls(
    List<BookSource> sources, {
    int limit = defaultAutoSelectLimit,
  }) {
    final ranked = List<BookSource>.of(sources);
    ranked.sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      if (byWeight != 0) return byWeight;
      final byResp = a.respondTime.compareTo(b.respondTime);
      if (byResp != 0) return byResp;
      return a.customOrder.compareTo(b.customOrder);
    });
    return ranked
        .take(limit < 1 ? 1 : limit)
        .map((source) => source.bookSourceUrl)
        .toList();
  }

  Future<void> _saveSelectedSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsSelectedSourcesKey,
        _selectedSourceUrls.toList(),
      );
    } catch (e) {
      debugPrint('保存搜索书源选择失败: $e');
    }
  }

  /// 从 prefs 还原选中的书源，整个生命周期只做一次。
  ///
  /// 原先这个选择只活在内存里，每次冷启动都退回默认值，用户手选等于白选。
  Future<void> _restoreSelectedSources() async {
    if (_selectionRestored) return;
    _selectionRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsSelectedSourcesKey);
      if (saved != null && saved.isNotEmpty) {
        _selectedSourceUrls = saved.toSet();
      }
    } catch (e) {
      debugPrint('读取搜索书源选择失败: $e');
    }
  }

  Future<void> loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _searchHistory = prefs.getStringList('searchHistory') ?? [];
      final savedConcurrent = prefs.getInt(_prefsConcurrentKey);
      if (savedConcurrent != null && savedConcurrent > 0) {
        _maxConcurrentSearches = savedConcurrent.clamp(1, 64);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('加载搜索历史失败: $e');
    }
  }

  Future<void> setMaxConcurrentSearches(int value) async {
    final next = value.clamp(1, 64);
    if (next == _maxConcurrentSearches) return;
    _maxConcurrentSearches = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsConcurrentKey, next);
    } catch (e) {
      debugPrint('保存搜索并发度失败: $e');
    }
  }

  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('searchHistory', _searchHistory);
    } catch (e) {
      debugPrint('保存搜索历史失败: $e');
    }
  }

  void toggleSourceSelection(String sourceUrl) {
    if (_selectedSourceUrls.contains(sourceUrl)) {
      _selectedSourceUrls.remove(sourceUrl);
    } else {
      _selectedSourceUrls.add(sourceUrl);
    }
    notifyListeners();
    unawaited(_saveSelectedSources());
  }

  void selectAllSources() {
    _selectedSourceUrls =
        _bookSources.map((source) => source.bookSourceUrl).toSet();
    notifyListeners();
    unawaited(_saveSelectedSources());
  }

  void deselectAllSources() {
    _selectedSourceUrls.clear();
    notifyListeners();
    unawaited(_saveSelectedSources());
  }

  void selectSingleSource(String sourceUrl) {
    // 单源路由是临时态，先记住原选择，返回时还原；这期间不落盘
    _selectionBeforeSingleSourceRoute ??= Set<String>.of(_selectedSourceUrls);
    _singleSourceRouteActive = true;
    _selectedSourceUrls = {
      if (_bookSources.any((s) => s.bookSourceUrl == sourceUrl)) sourceUrl,
    };
    notifyListeners();
  }

  void restoreMultiSourceSelectionAfterSingleSourceRoute() {
    if (!_singleSourceRouteActive) return;
    _singleSourceRouteActive = false;
    // 原先这里还原成「全部书源」，等于每次从单源搜索返回都把用户的选择冲掉。
    final previous = _selectionBeforeSingleSourceRoute;
    _selectionBeforeSingleSourceRoute = null;
    _selectedSourceUrls = previous ??
        pickDefaultSourceUrls(_bookSources).toSet();
    notifyListeners();
  }

  /// 选中指定分组的所有书源
  void selectGroupSources(String groupName) {
    _selectedSourceUrls = _bookSources
        .where((s) => (s.bookSourceGroup ?? '默认分组') == groupName)
        .map((s) => s.bookSourceUrl)
        .toSet();
    notifyListeners();
    unawaited(_saveSelectedSources());
  }

  /// 切换分组选中状态（全选/取消全选）
  void toggleGroupSelection(String groupName) {
    final groupSources = _bookSources
        .where((s) => (s.bookSourceGroup ?? '默认分组') == groupName)
        .toList();
    final allSelected = groupSources
        .every((s) => _selectedSourceUrls.contains(s.bookSourceUrl));
    if (allSelected) {
      for (final s in groupSources) {
        _selectedSourceUrls.remove(s.bookSourceUrl);
      }
    } else {
      for (final s in groupSources) {
        _selectedSourceUrls.add(s.bookSourceUrl);
      }
    }
    notifyListeners();
    unawaited(_saveSelectedSources());
  }

  Future<void> search(String keyword, {bool precisionSearch = false}) async {
    if (keyword.isEmpty) return;

    final generation = ++_searchGeneration;
    _currentKeyword = keyword;
    _isLoading = true;
    _error = null;
    _aggregator.clear();
    _aggregator.keyword = keyword;
    _sourceStatuses.clear();
    _finishedSourceCount = 0;
    notifyListeners();

    if (!_searchHistory.contains(keyword)) {
      _searchHistory.insert(0, keyword);
      if (_searchHistory.length > 20) {
        _searchHistory.removeLast();
      }
      unawaited(_saveSearchHistory());
    }

    final sources = selectedSources;
    _totalSourceCount = sources.length;
    if (sources.isEmpty) {
      _isLoading = false;
      _error = '请先选择书源';
      notifyListeners();
      return;
    }

    for (final source in sources) {
      _sourceStatuses[source.bookSourceUrl] = SourceSearchStatus(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
      );
    }
    notifyListeners();

    var nextSourceIndex = 0;

    Future<void> worker() async {
      while (generation == _searchGeneration) {
        final sourceIndex = nextSourceIndex++;
        if (sourceIndex >= sources.length) return;
        final source = sources[sourceIndex];
        final status = _sourceStatuses[source.bookSourceUrl];
        if (status == null) continue;

        status.phase = SourceSearchPhase.searching;
        notifyListeners();

        try {
          final results = await _searcher(source, keyword)
              .timeout(_perSourceTimeout);
          if (generation != _searchGeneration) {
            status.phase = SourceSearchPhase.cancelled;
            return;
          }

          var accepted = results;
          if (precisionSearch) {
            final keyLower = keyword.toLowerCase();
            accepted = results.where((r) {
              final name = r['name']?.toString().toLowerCase() ?? '';
              return name.contains(keyLower);
            }).toList();
          }

          if (accepted.isEmpty) {
            status.phase = SourceSearchPhase.noResults;
            status.resultCount = 0;
            status.message = '该源未找到匹配书籍';
          } else {
            _aggregator.addAll(
              accepted,
              sourceUrl: source.bookSourceUrl,
              sourceName: source.bookSourceName,
              sourceWeight: source.weight,
            );
            _aggregator.resort();
            status.phase = SourceSearchPhase.success;
            status.resultCount = accepted.length;
            status.message = null;
          }
        } on TimeoutException catch (e) {
          if (generation != _searchGeneration) {
            status.phase = SourceSearchPhase.cancelled;
            return;
          }
          status.phase = SourceSearchPhase.failed;
          status.failureKind = BookSearchFailureKind.timeout;
          status.message = '单源超时（${_perSourceTimeout.inSeconds}s）';
          debugPrint('搜索书源 ${source.bookSourceName} 超时: $e');
        } on BookSearchException catch (e) {
          if (generation != _searchGeneration) {
            status.phase = SourceSearchPhase.cancelled;
            return;
          }
          status.phase = SourceSearchPhase.failed;
          status.failureKind = e.kind;
          status.message = e.message;
          debugPrint('搜索书源 ${source.bookSourceName} 失败: $e');
        } catch (e) {
          if (generation != _searchGeneration) {
            status.phase = SourceSearchPhase.cancelled;
            return;
          }
          status.phase = SourceSearchPhase.failed;
          status.failureKind = BookSearchFailureKind.unknown;
          status.message = e.toString();
          debugPrint('搜索书源 ${source.bookSourceName} 失败: $e');
        } finally {
          if (generation == _searchGeneration) {
            _finishedSourceCount++;
            notifyListeners();
          }
        }
      }
    }

    final workerCount = sources.length < _maxConcurrentSearches
        ? sources.length
        : _maxConcurrentSearches;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    if (generation != _searchGeneration) return;

    _isLoading = false;
    if (_aggregator.results.isEmpty && failedSourceCount > 0) {
      _error = _buildAllFailedHint();
    }
    notifyListeners();
  }

  String _buildAllFailedHint() {
    final kinds = <BookSearchFailureKind, int>{};
    for (final s in _sourceStatuses.values) {
      if (s.phase != SourceSearchPhase.failed || s.failureKind == null) {
        continue;
      }
      kinds[s.failureKind!] = (kinds[s.failureKind!] ?? 0) + 1;
    }
    if (kinds.isEmpty) {
      return '搜索结束：无结果';
    }
    final parts = kinds.entries
        .map((e) => '${e.key.kindLabel} ${e.value}')
        .join('，');
    return '全部源未返回书籍（$parts）。可展开下方源状态查看详情。';
  }

  static Future<List<Map<String, dynamic>>> _searchSource(
    BookSource source,
    String keyword,
  ) {
    return WebBook(source).searchBook(keyword);
  }

  void clearResults() {
    _searchGeneration++;
    _aggregator.clear();
    _sourceStatuses.clear();
    _currentKeyword = '';
    _isLoading = false;
    _error = null;
    _finishedSourceCount = 0;
    _totalSourceCount = 0;
    notifyListeners();
  }

  void stopSearch() {
    _searchGeneration++;
    for (final status in _sourceStatuses.values) {
      if (!status.isDone) {
        status.phase = SourceSearchPhase.cancelled;
        status.message = '用户停止搜索';
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearHistory() {
    _searchHistory.clear();
    unawaited(_saveSearchHistory());
    notifyListeners();
  }

  void removeFromHistory(String keyword) {
    _searchHistory.remove(keyword);
    unawaited(_saveSearchHistory());
    notifyListeners();
  }
}
