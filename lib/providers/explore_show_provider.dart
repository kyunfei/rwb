import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/storage_service.dart';
import '../services/source_engine/source_engine.dart';
import '../services/source_request_failure.dart';

class ExploreShowProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  // ignore: unused_field
  int _currentPage = 1;

  List<Map<String, dynamic>> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadExploreBooks(String sourceUrl, String exploreUrl) async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    try {
      final sourceData = StorageService.instance.getBookSource(sourceUrl);
      if (sourceData == null) {
        _books = [];
        _error = '书源不存在，请返回重新选择。';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final source = BookSource.fromJson(sourceData);
      final webBook = WebBook(source);
      final results = await webBook.exploreBook(exploreUrl);

      _books = results;
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _books = [];
      _error = describeSourceRequestFailure(e);
      _isLoading = false;
      debugPrint('加载发现内容失败: $e');
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
  }

  void clear() {
    _books = [];
    _error = null;
    notifyListeners();
  }
}
