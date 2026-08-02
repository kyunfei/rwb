import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/book_source.dart';
import '../services/cover_config_service.dart';
import '../services/image_decode_provider.dart';
import '../services/storage_service.dart';
import '../utils/cover_headers.dart';

/// 书籍封面。
///
/// 封面不是「一个 URL 塞给 Image」那么简单，有两处容易漏：
/// 1. 防盗链——多数书源站点缺 Referer / User-Agent 会直接 403；
/// 2. 部分书源封面是加密的，要走 coverDecodeJs 解密（见 DecodedImageProvider）。
///
/// 书架原先把这两件事做在页面私有方法里，别处照抄成裸 CachedNetworkImage 就会
/// 出现「同一本书封面在书架有、在别处没有」。统一收到这里，避免再次漂移。
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    required this.isDark,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius,
    this.forceDefault = false,
    this.placeholderShowsTitle = true,
  });

  final Book book;
  final bool isDark;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  /// 调用方强制使用默认封面（书架的网格/列表模式会用到）
  final bool forceDefault;

  /// 缺封面时，占位图里是否写书名与作者。
  ///
  /// 书架网格封面下面没有文字，占位图必须自己写书名。但列表行里书名就在封面右边，
  /// 占位图再写一遍会在 52px 宽的方块里把书名挤成竖排（「百 炼 飞」），
  /// 反而比留白难看。这种场合传 false。
  final bool placeholderShowsTitle;

  static BookSource? _resolveSource(Book book) {
    final sourceUrl = book.sourceUrl;
    if (sourceUrl == null || sourceUrl.isEmpty) return null;
    final data = StorageService.instance.getBookSource(sourceUrl);
    if (data == null) return null;
    try {
      return BookSource.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 供页面复用：按书籍所属书源构建封面请求头
  static Map<String, String> headersFor(Book book) => buildCoverHeaders(
        source: _resolveSource(book),
        sourceUrl: book.sourceUrl,
      );

  @override
  Widget build(BuildContext context) {
    final coverConfig = CoverConfigService.instance;
    final basePlaceholder = coverConfig.buildDefaultCoverPlaceholder(
      bookName: placeholderShowsTitle ? book.displayName : '',
      bookAuthor: placeholderShowsTitle ? book.displayAuthor : '',
      isDark: isDark,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
    // 不写书名时会剩一个纯色方块，看着像加载失败，补一个淡书本图标
    final placeholder = placeholderShowsTitle
        ? basePlaceholder
        : Stack(
            alignment: Alignment.center,
            children: [
              basePlaceholder,
              Icon(
                Icons.menu_book_outlined,
                size: width.isFinite ? width * 0.4 : 24,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.18),
              ),
            ],
          );

    final coverUrl = book.displayCoverUrl;
    if (forceDefault || coverConfig.useDefaultCover || coverUrl.isEmpty) {
      return placeholder;
    }

    final source = _resolveSource(book);
    final headers = buildCoverHeaders(
      source: source,
      sourceUrl: book.sourceUrl,
    );

    if (DecodedImageProvider.needsDecode(source, true)) {
      return Image(
        image: DecodedImageProvider(
          url: coverUrl,
          headers: headers,
          source: source!,
          isCover: true,
          book: book,
        ),
        fit: BoxFit.cover,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    // 非高清时限制缓存尺寸，省内存与磁盘
    final highQuality = coverConfig.loadCoverHighQuality;
    return CachedNetworkImage(
      imageUrl: coverUrl,
      httpHeaders: headers,
      fit: BoxFit.cover,
      width: width,
      height: height,
      memCacheWidth: highQuality ? null : 240,
      maxWidthDiskCache: highQuality ? null : 320,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => placeholder,
    );
  }
}
