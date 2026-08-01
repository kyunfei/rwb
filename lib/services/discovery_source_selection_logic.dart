import '../models/book_source.dart';

/// 书城页上次手动选择的书源 URL（[StorageService.settings]）
const String discoveryLastSelectedSourceUrlKey = 'discoverySelectedSourceUrl';

/// 书源名称或分组名含 CJK 统一汉字时视为中文向书源（不绑定具体内置源名称）。
bool bookSourceLooksChinese(BookSource source) {
  return _stringContainsCjk(source.bookSourceName) ||
      _stringContainsCjk(source.bookSourceGroup);
}

bool _stringContainsCjk(String? text) {
  if (text == null || text.isEmpty) return false;
  for (final rune in text.runes) {
    if (rune >= 0x4E00 && rune <= 0x9FFF) return true;
    if (rune >= 0x3400 && rune <= 0x4DBF) return true;
  }
  return false;
}

/// 在已可发现的书源列表中解析应展示的书源 URL。
///
/// 优先级：上次手动选择（须在列表中）→ 置顶（customOrder < 0 且为当前最小）→
/// 中文向书源（列表顺序中首个）→ 列表首个。
String? resolveDiscoverySelectedSourceUrl({
  required List<BookSource> discoverable,
  String? lastSelectedUrl,
}) {
  if (discoverable.isEmpty) return null;

  if (lastSelectedUrl != null && lastSelectedUrl.isNotEmpty) {
    for (final source in discoverable) {
      if (source.bookSourceUrl == lastSelectedUrl) {
        return lastSelectedUrl;
      }
    }
  }

  var minOrder = discoverable.first.customOrder;
  for (final source in discoverable.skip(1)) {
    if (source.customOrder < minOrder) minOrder = source.customOrder;
  }
  if (minOrder < 0) {
    final pinned = discoverable
        .where((source) => source.customOrder == minOrder)
        .toList();
    return _pickByChineseThenFirst(pinned);
  }

  for (final source in discoverable) {
    if (bookSourceLooksChinese(source)) {
      return source.bookSourceUrl;
    }
  }

  return discoverable.first.bookSourceUrl;
}

String _pickByChineseThenFirst(List<BookSource> candidates) {
  for (final source in candidates) {
    if (bookSourceLooksChinese(source)) {
      return source.bookSourceUrl;
    }
  }
  return candidates.first.bookSourceUrl;
}
