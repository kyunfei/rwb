import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/book_source.dart';
import 'storage_service.dart';

/// 首启注入所需的最小存储接口（便于单测用内存实现）。
abstract class BuiltinSourceSeedStore {
  bool get isInitialized;
  dynamic getSetting(String key, {dynamic defaultValue});
  Future<void> setSetting(String key, dynamic value);
  Map<String, dynamic>? getBookSource(String sourceUrl);
  Future<void> saveBookSource(Map<String, dynamic> sourceData);
}

/// 对接 [StorageService] 的默认实现。
class StorageBuiltinSourceSeedStore implements BuiltinSourceSeedStore {
  StorageBuiltinSourceSeedStore(this._storage);

  final StorageService _storage;

  @override
  bool get isInitialized => _storage.isInitialized;

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      _storage.getSetting(key, defaultValue: defaultValue);

  @override
  Future<void> setSetting(String key, dynamic value) =>
      _storage.setSetting(key, value);

  @override
  Map<String, dynamic>? getBookSource(String sourceUrl) =>
      _storage.getBookSource(sourceUrl);

  @override
  Future<void> saveBookSource(Map<String, dynamic> sourceData) =>
      _storage.saveBookSource(sourceData);
}

/// 内置书源（assets/book_sources/）加载与一次性注入。
///
/// 仅补齐本地缺失的 bookSourceUrl，不覆盖用户已修改的同 URL 源。
class BuiltinBookSourceService {
  BuiltinBookSourceService._();

  /// v1 仅注入了 3 个英文源；v2 起包含中文示例源 ppxsw；
  /// v3 起包含中文维基文库公有领域源。
  /// 旧用户已置 true 的较低版本标记不会阻止较高版本补种。
  static const String legacySeededFlagKey = 'builtin_english_sources_seeded_v1';
  static const String previousSeededFlagKey = 'builtin_sources_seeded_v2';
  static const String seededFlagKey = 'builtin_sources_seeded_v3';

  /// 内置书源资源路径（中文维基文库、中文示例源与三个公有领域英文源）。
  static const List<String> assetPaths = [
    'assets/book_sources/chinese_wikisource.json',
    'assets/book_sources/ppxsw.json',
    'assets/book_sources/project_gutenberg.json',
    'assets/book_sources/english_wikisource.json',
    'assets/book_sources/standard_ebooks.json',
  ];

  /// 从 JSON 文本解析书源（单对象或数组）。
  static List<BookSource> parseSourcesJson(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      return [
        BookSource.fromJson(Map<String, dynamic>.from(decoded)),
      ];
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => BookSource.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.bookSourceUrl.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// 读取 assets 中的内置书源。
  static Future<List<BookSource>> loadSourcesFromAssets() async {
    final out = <BookSource>[];
    for (final path in assetPaths) {
      try {
        final text = await rootBundle.loadString(path);
        out.addAll(parseSourcesJson(text));
      } catch (e, st) {
        debugPrint('⚠️ BuiltinBookSourceService: 加载 $path 失败: $e\n$st');
      }
    }
    return out;
  }

  /// 首次启动 / 版本升级注入：只添加本地尚不存在的源，不覆盖已有同 URL 源。
  ///
  /// 返回本次新增条数。已打上 [seededFlagKey] 则直接返回 0（幂等）。
  static Future<int> ensureBuiltinSourcesSeeded({
    StorageService? storage,
    BuiltinSourceSeedStore? store,
    Future<List<BookSource>> Function()? loadSources,
  }) async {
    final seedStore =
        store ?? StorageBuiltinSourceSeedStore(storage ?? StorageService.instance);
    if (!seedStore.isInitialized) return 0;
    final already = seedStore.getSetting(seededFlagKey, defaultValue: false);
    if (already == true) return 0;

    final loader = loadSources ?? loadSourcesFromAssets;
    final sources = await loader();
    var added = 0;
    for (final source in sources) {
      final url = source.bookSourceUrl;
      if (url.isEmpty) continue;
      if (seedStore.getBookSource(url) != null) continue;
      await seedStore.saveBookSource(source.toJson());
      added++;
    }
    await seedStore.setSetting(seededFlagKey, true);
    return added;
  }
}
