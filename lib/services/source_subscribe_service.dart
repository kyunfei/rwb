import '../models/source_subscription.dart';
import 'book_source_import_service.dart';
import 'source_import_logic.dart';
import 'storage_service.dart';

/// 书源订阅管理：记住远程地址，支持单条/全部更新，按 bookSourceUrl 去重合并。
class SourceSubscribeService {
  static const String storageKey = 'bookSourceSubscriptions';

  final StorageService storage;
  final BookSourceImportService importService;

  SourceSubscribeService({
    StorageService? storage,
    BookSourceImportService? importService,
  })  : storage = storage ?? StorageService.instance,
        importService = importService ?? BookSourceImportService(storage: storage);

  List<SourceSubscription> list() {
    final raw = storage.getSetting(storageKey);
    if (raw is! List) return const [];
    final result = <SourceSubscription>[];
    for (final item in raw) {
      if (item is Map) {
        final sub = SourceSubscription.fromJson(
          item.map((k, v) => MapEntry('$k', v)),
        );
        if (sub.url.trim().isNotEmpty) {
          result.add(sub);
        }
      } else if (item is String && looksLikeSubscribeUrl(item)) {
        result.add(SourceSubscription(url: item.trim()));
      }
    }
    return result;
  }

  Future<void> _save(List<SourceSubscription> list) async {
    await storage.setSetting(
      storageKey,
      list.map((e) => e.toJson()).toList(),
    );
  }

  /// 添加订阅地址；可选立即拉取导入
  Future<BookSourceImportResult?> add(
    String url, {
    bool importNow = true,
    String? name,
  }) async {
    final trimmed = url.trim();
    if (!looksLikeSubscribeUrl(trimmed)) {
      throw FormatException('无效的订阅地址: $url');
    }

    var subs = upsertSubscription(
      list(),
      SourceSubscription(url: trimmed, name: name),
    );
    await _save(subs);

    if (!importNow) return null;
    return updateOne(trimmed);
  }

  Future<void> remove(String url) async {
    await _save(removeSubscription(list(), url.trim()));
  }

  /// 更新单条订阅：拉取远程 JSON 并按 bookSourceUrl 去重更新本地书源
  Future<BookSourceImportResult> updateOne(String url) async {
    final trimmed = url.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await importService.importText(trimmed);
      final name = result.sources.isNotEmpty
          ? (result.sources.length == 1
              ? result.sources.first.bookSourceName
              : '${result.sources.first.bookSourceName} 等${result.sources.length}个')
          : null;
      final updated = upsertSubscription(
        list(),
        SourceSubscription(
          url: trimmed,
          name: name,
          lastUpdateTime: now,
          lastAdded: result.added,
          lastUpdated: result.updated,
          lastUnchanged: result.unchanged,
        ),
      );
      await _save(updated);
      return result;
    } catch (e) {
      final updated = upsertSubscription(
        list(),
        SourceSubscription(
          url: trimmed,
          lastUpdateTime: now,
          lastError: e.toString(),
        ),
      );
      await _save(updated);
      rethrow;
    }
  }

  /// 一键更新全部订阅
  Future<List<({String url, BookSourceImportResult? result, Object? error})>>
      updateAll({
    void Function(int done, int total, String url)? onProgress,
  }) async {
    final subs = list();
    final outcomes =
        <({String url, BookSourceImportResult? result, Object? error})>[];
    for (var i = 0; i < subs.length; i++) {
      final url = subs[i].url;
      onProgress?.call(i, subs.length, url);
      try {
        final result = await updateOne(url);
        outcomes.add((url: url, result: result, error: null));
      } catch (e) {
        outcomes.add((url: url, result: null, error: e));
      }
    }
    onProgress?.call(subs.length, subs.length, '');
    return outcomes;
  }
}
