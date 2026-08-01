import 'book_search_exception.dart';

/// 单个书源在本轮搜索中的状态。
enum SourceSearchPhase {
  pending,
  searching,
  success,
  noResults,
  failed,
  cancelled,
}

class SourceSearchStatus {
  SourceSearchStatus({
    required this.sourceUrl,
    required this.sourceName,
    this.phase = SourceSearchPhase.pending,
    this.resultCount = 0,
    this.failureKind,
    this.message,
  });

  final String sourceUrl;
  final String sourceName;
  SourceSearchPhase phase;
  int resultCount;
  BookSearchFailureKind? failureKind;
  String? message;

  bool get isDone =>
      phase == SourceSearchPhase.success ||
      phase == SourceSearchPhase.noResults ||
      phase == SourceSearchPhase.failed ||
      phase == SourceSearchPhase.cancelled;

  String get statusLabel {
    switch (phase) {
      case SourceSearchPhase.pending:
        return '等待中';
      case SourceSearchPhase.searching:
        return '搜索中';
      case SourceSearchPhase.success:
        return '找到 $resultCount 本';
      case SourceSearchPhase.noResults:
        return '无结果';
      case SourceSearchPhase.failed:
        return failureKind?.kindLabel ?? '失败';
      case SourceSearchPhase.cancelled:
        return '已取消';
    }
  }

  String get detailMessage {
    if (message != null && message!.isNotEmpty) return message!;
    return statusLabel;
  }
}
