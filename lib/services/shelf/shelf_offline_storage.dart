import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/book.dart';
import '../chapter_cache_service.dart';

class ShelfOfflineStorage {
  ShelfOfflineStorage._();

  static Future<Directory?> bookCacheDirectory(Book book) async {
    await ChapterCacheService.instance.init();
    final docs = await getApplicationDocumentsDirectory();
    final folderName = ChapterCacheService.instance.getBookFolderName(book);
    final dir = Directory('${docs.path}book_cache/$folderName');
    if (!await dir.exists()) return null;
    return dir;
  }

  static Future<int> bookCacheBytes(Book book) async {
    final dir = await bookCacheDirectory(book);
    if (dir == null) return 0;
    return _dirSize(dir);
  }

  static Future<int> totalCacheBytes() async {
    return ChapterCacheService.instance.getCacheSize();
  }

  static Future<void> clearBookCache(Book book) async {
    await ChapterCacheService.instance.clearBookCache(book);
  }

  static String formatBytes(int bytes) {
    return ChapterCacheService.instance.formatCacheSize(bytes);
  }

  static Future<int> _dirSize(Directory dir) async {
    var size = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          size += await entity.length();
        } catch (_) {}
      }
    }
    return size;
  }
}
