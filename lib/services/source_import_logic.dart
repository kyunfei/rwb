import 'dart:convert';

import '../models/book_source.dart';
import '../models/source_subscription.dart';

/// 导入合并统计（纯逻辑，便于单测）
class SourceImportMergeStats {
  final int added;
  final int updated;
  final int unchanged;

  const SourceImportMergeStats({
    required this.added,
    required this.updated,
    required this.unchanged,
  });
}

/// 按 bookSourceUrl 去重：后出现的覆盖先出现的
List<BookSource> dedupeSourcesByUrl(Iterable<BookSource> sources) {
  final map = <String, BookSource>{};
  for (final source in sources) {
    final url = source.bookSourceUrl.trim();
    if (url.isEmpty) continue;
    map[url] = source;
  }
  return map.values.toList();
}

/// 对比本地已有书源与待导入书源，统计新增/更新/未变。
/// [existingByUrl] key 为 bookSourceUrl，value 为本地 JSON。
SourceImportMergeStats computeImportMergeStats({
  required List<BookSource> incoming,
  required Map<String, Map<String, dynamic>> existingByUrl,
}) {
  var added = 0;
  var updated = 0;
  var unchanged = 0;
  for (final source in incoming) {
    final old = existingByUrl[source.bookSourceUrl];
    if (old == null) {
      added++;
    } else if (jsonEncode(old) == jsonEncode(source.toJson())) {
      unchanged++;
    } else {
      updated++;
    }
  }
  return SourceImportMergeStats(
    added: added,
    updated: updated,
    unchanged: unchanged,
  );
}

/// 订阅列表按 url 去重合并；同一 url 保留新记录字段，保留旧的 name（若新 name 为空）
List<SourceSubscription> upsertSubscription(
  List<SourceSubscription> current,
  SourceSubscription next,
) {
  final result = <SourceSubscription>[];
  var replaced = false;
  for (final item in current) {
    if (item.url == next.url) {
      result.add(next.copyWith(
        name: (next.name != null && next.name!.trim().isNotEmpty)
            ? next.name
            : item.name,
      ));
      replaced = true;
    } else {
      result.add(item);
    }
  }
  if (!replaced) {
    result.add(next);
  }
  return result;
}

List<SourceSubscription> removeSubscription(
  List<SourceSubscription> current,
  String url,
) {
  return current.where((e) => e.url != url).toList();
}

/// 判断文本是否像可订阅的 HTTP(S) URL
bool looksLikeSubscribeUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
