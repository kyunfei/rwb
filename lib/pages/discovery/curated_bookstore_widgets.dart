import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/curated_bookstore.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/book_cover.dart';

/// 把策展条目转成 [BookCover] 可用的轻量 [Book]。
Book curatedBookToDisplayBook(CuratedBook book, {String? coverUrl}) {
  return Book(
    bookUrl: 'curated://${book.id}',
    name: book.name,
    author: book.author,
    coverUrl: coverUrl ?? book.coverUrl,
    intro: book.intro,
    kind: book.category,
    mediaType: MediaType.novel,
    originType: BookOriginType.online,
    addedTime: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

IconData shortcutIconData(String icon) {
  switch (icon) {
    case 'recommend':
    case 'auto_stories':
      return Icons.auto_stories_outlined;
    case 'favorite':
    case 'collect':
      return Icons.favorite_border;
    case 'star':
    case 'rating':
      return Icons.star_border_rounded;
    case 'done_all':
    case 'complete':
      return Icons.done_all;
    case 'local_fire_department':
    case 'hotupdate':
    case 'whatshot':
      return Icons.local_fire_department_outlined;
    default:
      return Icons.menu_book_outlined;
  }
}

/// 精选页轮播。
class CuratedBannerCarousel extends StatefulWidget {
  final List<CuratedBanner> banners;
  final CuratedBookstore data;
  final String Function(CuratedBook book) coverUrlFor;
  final ValueChanged<CuratedBook> onBookTap;

  const CuratedBannerCarousel({
    super.key,
    required this.banners,
    required this.data,
    required this.coverUrlFor,
    required this.onBookTap,
  });

  @override
  State<CuratedBannerCarousel> createState() => _CuratedBannerCarouselState();
}

class _CuratedBannerCarouselState extends State<CuratedBannerCarousel> {
  late final PageController _controller;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant CuratedBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7.2,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final banner = widget.banners[i];
              final book = widget.data.bookById(banner.bookId);
              if (book == null) {
                return _BannerPlaceholder(
                  tagline: banner.tagline.isEmpty ? '精选推荐' : banner.tagline,
                  colorScheme: colorScheme,
                );
              }
              final coverUrl = widget.coverUrlFor(book);
              return Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onBookTap(book),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BookCover(
                        book: curatedBookToDisplayBook(book, coverUrl: coverUrl),
                        isDark: isDark,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.zero,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: DesignTokens.spacingLg,
                        right: DesignTokens.spacingLg,
                        bottom: DesignTokens.spacingMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (banner.tagline.isNotEmpty)
                              Text(
                                banner.tagline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: DesignTokens.fontBody,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              book.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: DesignTokens.fontCaption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: DesignTokens.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  final String tagline;
  final ColorScheme colorScheme;

  const _BannerPlaceholder({
    required this.tagline,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      child: Text(
        tagline,
        textAlign: TextAlign.center,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// 五个圆形快捷入口。
class CuratedShortcutRow extends StatelessWidget {
  final List<CuratedShortcut> shortcuts;
  final ValueChanged<CuratedShortcut> onTap;

  const CuratedShortcutRow({
    super.key,
    required this.shortcuts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final sc in shortcuts)
          Expanded(
            child: InkWell(
              onTap: () => onTap(sc),
              borderRadius: BorderRadius.circular(40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spacingSm,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        shortcutIconData(sc.icon),
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacingXs),
                    Text(
                      sc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesignTokens.fontCaption,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 热门连载式横排列表项：封面 + 书名 + 简介 + 作者 + 分类。
class CuratedBookListTile extends StatelessWidget {
  final CuratedBook book;
  final String coverUrl;
  final VoidCallback onTap;
  final int? rank;

  const CuratedBookListTile({
    super.key,
    required this.book,
    required this.coverUrl,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: DesignTokens.spacingSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rank != null) ...[
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSubtitle,
                      fontWeight: FontWeight.w700,
                      color: rank! <= 3
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.actionRadius),
                child: SizedBox(
                  width: 64,
                  height: 86,
                  child: BookCover(
                    book: curatedBookToDisplayBook(book, coverUrl: coverUrl),
                    isDark: isDark,
                    width: 64,
                    height: 86,
                    placeholderShowsTitle: false,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: SizedBox(
                  height: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSubtitle,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 策展清单里只有少部分书带简介（站点分类页不给），
                      // 缺简介时留白比写「暂无简介」干净——那行字每条都出现一遍，
                      // 整屏读下来只剩噪声。
                      Expanded(
                        child: book.intro.isEmpty
                            ? const SizedBox.shrink()
                            : Text(
                                book.intro,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: DesignTokens.fontCaption,
                                  height: 1.35,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              book.author.isNotEmpty ? book.author : '佚名',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: DesignTokens.fontCaption,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (book.category.isNotEmpty) ...[
                            const SizedBox(width: DesignTokens.spacingSm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                book.category,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分类/榜单顶部的横向 chip 选择条。
class CuratedChipBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CuratedChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DesignTokens.spacingSm),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return ChoiceChip(
            label: Text(labels[i]),
            selected: selected,
            showCheckmark: false,
            selectedColor: colorScheme.primary.withValues(alpha: 0.14),
            labelStyle: TextStyle(
              fontSize: DesignTokens.fontCaption,
              color: selected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            backgroundColor: colorScheme.surfaceContainerHighest,
            side: BorderSide.none,
            onSelected: (_) => onSelected(i),
          );
        },
      ),
    );
  }
}

/// 书单卡片（书单 tab）。
class CuratedListCard extends StatelessWidget {
  final CuratedBookList list;
  final List<CuratedBook> previewBooks;
  final String Function(CuratedBook book) coverUrlFor;
  final VoidCallback onTap;

  const CuratedListCard({
    super.key,
    required this.list,
    required this.previewBooks,
    required this.coverUrlFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.title,
                style: TextStyle(
                  fontSize: DesignTokens.fontSubtitle,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (list.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  list.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignTokens.fontCaption,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spacingMd),
              if (previewBooks.isEmpty)
                Text(
                  '书单暂无书籍',
                  style: TextStyle(
                    fontSize: DesignTokens.fontCaption,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      for (var i = 0; i < previewBooks.length && i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: DesignTokens.spacingSm),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(DesignTokens.actionRadius),
                          child: SizedBox(
                            width: 52,
                            height: 72,
                            child: BookCover(
                              book: curatedBookToDisplayBook(
                                previewBooks[i],
                                coverUrl: coverUrlFor(previewBooks[i]),
                              ),
                              isDark: isDark,
                              width: 52,
                              height: 72,
                              placeholderShowsTitle: false,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空列表占位。
class CuratedEmptyHint extends StatelessWidget {
  final String message;

  const CuratedEmptyHint({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacingXxl),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
