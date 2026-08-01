import '../models/book.dart';

/// 从书架中选取最近阅读的书（按 [Book.durChapterTime] 最新）。
///
/// - 书架为空 → null
/// - 全部书的 [Book.durChapterTime] 为 null → null（从未读过）
/// - 部分为 null → 在有值的书里选最新
/// - 多本都有值 → 选最新
Book? pickLatestReadingBook(Iterable<Book> books) {
  Book? latest;
  for (final book in books) {
    final time = book.durChapterTime;
    if (time == null) continue;
    final latestTime = latest?.durChapterTime;
    if (latest == null || latestTime == null || time.isAfter(latestTime)) {
      latest = book;
    }
  }
  return latest;
}
