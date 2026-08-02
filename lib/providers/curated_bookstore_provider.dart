import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/book_source.dart';
import '../models/curated_bookstore.dart';
import '../services/bookstore/curated_cover_resolver.dart';

/// 策展书城数据 + 惰性封面状态。
class CuratedBookstoreProvider extends ChangeNotifier {
  CuratedBookstoreProvider({
    this.assetPath = 'assets/bookstore/curated.json',
    CuratedCoverResolver? coverResolver,
    this._bundle,
  }) : _coverResolver = coverResolver ?? CuratedCoverResolver();

  static const String defaultAssetPath = 'assets/bookstore/curated.json';

  final String assetPath;
  final CuratedCoverResolver _coverResolver;
  final AssetBundle? _bundle;

  CuratedBookstore _data = CuratedBookstore.empty;
  bool _loading = false;
  bool _loaded = false;
  String? _loadError;

  /// bookId → 解析到的封面 URL（覆盖 JSON 内空封面）
  final Map<String, String> _resolvedCovers = {};

  CuratedBookstore get data => _data;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get loadError => _loadError;
  CuratedCoverResolver get coverResolver => _coverResolver;

  String coverUrlFor(CuratedBook book) {
    final resolved = _resolvedCovers[book.id];
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final cached = _coverResolver.cachedCoverUrl(book);
    if (cached != null && cached.isNotEmpty) return cached;
    return book.coverUrl;
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final bundle = _bundle ?? rootBundle;
      final raw = await bundle.loadString(assetPath);
      _data = parseCuratedBookstoreJson(raw);
      if (_data.isEmpty) {
        _loadError = '策展清单为空或无法解析，请检查资源文件。';
      }
      _loaded = true;
    } catch (e) {
      debugPrint('加载策展书城失败: $e');
      _data = CuratedBookstore.empty;
      _loadError = '无法加载书城内容，请稍后重试。';
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 暂停后台封面解析，让点书这类交互路径独占网络。与 [resumeCovers] 配对，
  /// 解析器内部按引用计数，重叠调用是安全的。
  void pauseCovers() => _coverResolver.pause();

  void resumeCovers() => _coverResolver.resume();

  /// 为可见书籍排队封面解析。
  void requestCovers(
    Iterable<CuratedBook> books, {
    required List<BookSource> sources,
  }) {
    _coverResolver.prefetchVisible(
      books.where((b) {
        final url = coverUrlFor(b);
        return url.isEmpty;
      }),
      sources: sources,
      onResolved: (bookId, coverUrl) {
        if (_resolvedCovers[bookId] == coverUrl) return;
        _resolvedCovers[bookId] = coverUrl;
        notifyListeners();
      },
    );
  }
}
