import '../../models/chapter.dart';
import '../../models/shelf/shelf_toc_entry.dart';

/// 目录差异比对结果
class ShelfChapterDiffResult {
  final bool isFirstSnapshot;
  final bool hasNewChapters;
  final int newChapterCount;
  final List<String> newChapterTitles;
  final int removedChapterCount;
  final int renamedChapterCount;

  const ShelfChapterDiffResult({
    this.isFirstSnapshot = false,
    this.hasNewChapters = false,
    this.newChapterCount = 0,
    this.newChapterTitles = const [],
    this.removedChapterCount = 0,
    this.renamedChapterCount = 0,
  });
}

/// 基于 URL/标题的目录差异比对（不依赖章节总数）
class ShelfChapterDiff {
  ShelfChapterDiff._();

  static List<ShelfTocEntry> fromChapters(List<Chapter> chapters) {
    return chapters
        .map(
          (c) => ShelfTocEntry(
            title: c.title,
            url: c.url,
            isVolume: c.isVolume,
          ),
        )
        .toList();
  }

  static List<ShelfTocEntry> readableEntries(List<ShelfTocEntry> entries) {
    return entries
        .where(
          (e) =>
              !e.isVolume &&
              e.url != null &&
              e.url!.trim().isNotEmpty,
        )
        .toList();
  }

  static ShelfChapterDiffResult compare(
    List<ShelfTocEntry> previous,
    List<ShelfTocEntry> current,
  ) {
    final oldList = readableEntries(previous);
    final newList = readableEntries(current);

    if (oldList.isEmpty) {
      return const ShelfChapterDiffResult(isFirstSnapshot: true);
    }

    final oldByUrl = <String, ShelfTocEntry>{
      for (final e in oldList)
        if (e.url != null) e.url!: e,
    };
    final newByUrl = <String, ShelfTocEntry>{
      for (final e in newList)
        if (e.url != null) e.url!: e,
    };

    var renamed = 0;
    for (final entry in newList) {
      final url = entry.url;
      if (url == null) continue;
      final prior = oldByUrl[url];
      if (prior != null && prior.title != entry.title) {
        renamed++;
      }
    }

    final removed = oldList
        .where((e) => e.url != null && !newByUrl.containsKey(e.url))
        .length;

    final newlyAdded = newList
        .where((e) => e.url != null && !oldByUrl.containsKey(e.url!))
        .toList();

    var hasNew = newlyAdded.isNotEmpty;

    // 末章变化（换 URL 或换标题）也算有更新，避免仅改最后一章时漏报
    if (!hasNew && newList.isNotEmpty && oldList.isNotEmpty) {
      final oldLast = oldList.last;
      final newLast = newList.last;
      if (oldLast.url != newLast.url &&
          !oldByUrl.containsKey(newLast.url)) {
        hasNew = true;
      } else if (oldLast.url == newLast.url && oldLast.title != newLast.title) {
        hasNew = true;
      }
    }

    final newTitles = newlyAdded.map((e) => e.title).toList();
    var newCount = newlyAdded.length;
    if (hasNew && newCount == 0) {
      newCount = 1;
    }

    return ShelfChapterDiffResult(
      hasNewChapters: hasNew,
      newChapterCount: newCount,
      newChapterTitles: newTitles,
      removedChapterCount: removed,
      renamedChapterCount: renamed,
    );
  }
}
