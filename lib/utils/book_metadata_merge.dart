import '../models/book.dart';

/// 书籍元数据字段是否视为「未取到」（null、空串、纯空白）。
bool isMissingBookField(String? value) =>
    value == null || value.trim().isEmpty;

/// 详情页（primary）优先；字段缺失时回退到搜索/已知书籍（fallback）。
/// [tocUrlFallback]：详情与搜索均无目录地址时，回退为书籍详情页 URL。
Book mergeBookMetadata(
  Book primary,
  Book fallback, {
  String? tocUrlFallback,
}) {
  String prefer(String value, String fallbackValue) =>
      !isMissingBookField(value) ? value : fallbackValue;
  String? preferNullable(String? value, String? fallbackValue) =>
      !isMissingBookField(value) ? value : fallbackValue;

  final primaryTags = primary.tags ?? const <String>[];
  final fallbackTags = fallback.tags ?? const <String>[];
  final kind = preferNullable(primary.kind, fallback.kind);

  var tocUrl = preferNullable(primary.tocUrl, fallback.tocUrl);
  if (isMissingBookField(tocUrl) &&
      !isMissingBookField(tocUrlFallback)) {
    tocUrl = tocUrlFallback!.trim();
  }

  return primary.copyWith(
    bookUrl: prefer(primary.bookUrl, fallback.bookUrl),
    name: prefer(primary.name, fallback.name),
    author: prefer(primary.author, fallback.author),
    coverUrl: prefer(primary.coverUrl, fallback.coverUrl),
    intro: prefer(primary.intro, fallback.intro),
    mediaType: primary.mediaType,
    originType: fallback.originType,
    sourceUrl: preferNullable(primary.sourceUrl, fallback.sourceUrl),
    sourceName: preferNullable(primary.sourceName, fallback.sourceName),
    kind: kind,
    lastChapter: preferNullable(primary.lastChapter, fallback.lastChapter),
    totalChapterNum: primary.totalChapterNum ?? fallback.totalChapterNum,
    status: preferNullable(primary.status, fallback.status),
    tags: primaryTags.isNotEmpty
        ? primaryTags
        : fallbackTags.isNotEmpty
            ? fallbackTags
            : _tagsFromKind(kind),
    tocUrl: tocUrl,
    wordCount: preferNullable(primary.wordCount, fallback.wordCount),
  );
}

List<String>? _tagsFromKind(String? kind) {
  if (isMissingBookField(kind)) return null;
  final tags = kind!
      .split(RegExp(r'[,，/|·\s]+'))
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();
  return tags.isEmpty ? null : tags;
}
