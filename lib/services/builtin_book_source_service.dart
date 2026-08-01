import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/book_source.dart';
import 'storage_service.dart';

/// 内置书源（assets/book_sources/）加载与一次性注入。
///
/// 仅补齐本地缺失的 bookSourceUrl，不覆盖用户已修改的同名源。
class BuiltinBookSourceService {
  BuiltinBookSourceService._();

  static const String seededFlagKey = 'builtin_english_sources_seeded_v1';

  /// 内置英文源资源路径（不含示例中文源 ppxsw，避免强行注入中文站）。
  static const List<String> englishAssetPaths = [
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

  /// 读取 assets 中的英文内置书源。
  static Future<List<BookSource>> loadEnglishSourcesFromAssets() async {
    final out = <BookSource>[];
    for (final path in englishAssetPaths) {
      try {
        final text = await rootBundle.loadString(path);
        out.addAll(parseSourcesJson(text));
      } catch (e) {
        debugPrint('⚠️ BuiltinBookSourceService: 加载 $path 失败: $e');
      }
    }
    return out;
  }

  /// 首次启动注入：只添加本地尚不存在的源。
  static Future<int> ensureEnglishSourcesSeeded({
    StorageService? storage,
  }) async {
    final store = storage ?? StorageService.instance;
    if (!store.isInitialized) return 0;
    final already = store.getSetting(seededFlagKey, defaultValue: false);
    if (already == true) return 0;

    final sources = await loadEnglishSourcesFromAssets();
    var added = 0;
    for (final source in sources) {
      final url = source.bookSourceUrl;
      if (url.isEmpty) continue;
      if (store.getBookSource(url) != null) continue;
      await store.saveBookSource(source.toJson());
      added++;
    }
    await store.setSetting(seededFlagKey, true);
    return added;
  }
}
