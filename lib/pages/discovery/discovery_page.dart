import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/book_source.dart';
import '../../providers/bookshelf_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/discovery_source_selection_logic.dart';
import '../../services/storage_service.dart';
import '../../utils/continue_reading.dart';
import '../../utils/design_tokens.dart';
import '../../utils/explore_category_parser.dart';
import '../../widgets/book_cover.dart';

/// 书城页：分类网格 + 搜书 + 继续阅读
///
/// 对普通读者隐藏「书源」概念：进页即展示可用书源的分类；
/// 书源切换入口放在 AppBar 右侧，保持低调。
class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// 当前选中的可发现书源 URL；null 表示尚未选定（按默认策略解析）
  String? _selectedSourceUrl;

  @override
  void initState() {
    super.initState();
    final saved = StorageService.instance
        .getSetting(discoveryLastSelectedSourceUrlKey);
    if (saved is String && saved.isNotEmpty) {
      _selectedSourceUrl = saved;
    }
  }

  /// 按书源 URL 缓存分类解析结果
  final Map<String, List<ExploreCategory>> _cachedCategories = {};

  /// 已启用且开启发现、并能解析出分类的书源
  List<BookSource> _discoverableSources(List<BookSource> all) {
    return all.where((s) {
      if (!s.enabled || !s.enabledExplore) return false;
      return _categoriesFor(s).isNotEmpty;
    }).toList();
  }

  List<ExploreCategory> _categoriesFor(BookSource source) {
    final key = source.bookSourceUrl;
    final cached = _cachedCategories[key];
    if (cached != null) return cached;
    final parsed = flattenExploreCategories(
      parseExploreKinds(source.exploreUrl),
    );
    _cachedCategories[key] = parsed;
    return parsed;
  }

  BookSource? _resolveSelectedSource(List<BookSource> discoverable) {
    final url = resolveDiscoverySelectedSourceUrl(
      discoverable: discoverable,
      lastSelectedUrl: _selectedSourceUrl,
    );
    if (url == null) return null;
    for (final source in discoverable) {
      if (source.bookSourceUrl == url) return source;
    }
    return null;
  }

  void _persistDiscoverySourceChoice(String url) {
    StorageService.instance.setSetting(
      discoveryLastSelectedSourceUrlKey,
      url,
    );
  }

  void _openSearch() {
    Navigator.pushNamed(context, AppRoutes.search);
  }

  void _openExplore(BookSource source, ExploreCategory category) {
    Navigator.pushNamed(
      context,
      AppRoutes.exploreShow,
      arguments: {
        'sourceUrl': source.bookSourceUrl,
        'sourceName': source.bookSourceName,
        'exploreName': category.title,
        'exploreUrl': category.url,
      },
    );
  }

  Future<void> _continueReading(Book book) async {
    final route = switch (book.mediaType) {
      MediaType.comic => AppRoutes.comicReader,
      MediaType.novel || MediaType.video || MediaType.audio =>
        AppRoutes.novelReader,
    };
    await Navigator.pushNamed(
      context,
      route,
      arguments: {
        'bookUrl': book.bookUrl,
        'bookId': book.bookUrl,
        'bookData': book,
        // 与书架页一致：由阅读器从 Book.durChapterIndex / durChapterPos 恢复
        'resumeProgress': true,
      },
    );
    if (!mounted) return;
    await context.read<BookshelfProvider>().loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(colorScheme),
          Expanded(
            child: Consumer2<DiscoveryProvider, BookshelfProvider>(
              builder: (context, discovery, bookshelf, _) {
                if (discovery.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allSources = discovery.bookSources;
                // 书源列表变化时清缓存，避免 exploreUrl 更新后仍用旧解析
                if (_cachedCategories.isNotEmpty &&
                    !_cachedCategories.keys.every(
                      (url) => allSources.any((s) => s.bookSourceUrl == url),
                    )) {
                  _cachedCategories.clear();
                }

                final hasAnySource = allSources.isNotEmpty;
                final discoverable = _discoverableSources(allSources);
                final selected = _resolveSelectedSource(discoverable);
                final continueBook =
                    pickLatestReadingBook(bookshelf.allBooks);

                if (!hasAnySource) {
                  return _buildEmptyState(
                    icon: Icons.cloud_download_outlined,
                    message: '还没有书源，去导入后就能逛书城',
                    colorScheme: colorScheme,
                    actionText: '去导入书源',
                    onAction: () => Navigator.pushNamed(
                      context,
                      AppRoutes.bookSourceImport,
                    ),
                  );
                }

                if (discoverable.isEmpty || selected == null) {
                  return _buildEmptyState(
                    icon: Icons.explore_outlined,
                    message: '已有书源暂无分类，试试导入带发现页的书源',
                    colorScheme: colorScheme,
                    actionText: '去导入书源',
                    onAction: () => Navigator.pushNamed(
                      context,
                      AppRoutes.bookSourceImport,
                    ),
                    secondaryText: '或到「我的 → 书源管理」检查是否已启用发现',
                    secondaryActionText: '打开书源管理',
                    onSecondaryAction: () => Navigator.pushNamed(
                      context,
                      AppRoutes.bookSourceManage,
                    ),
                  );
                }

                final categories = _categoriesFor(selected);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spacingLg,
                    DesignTokens.spacingSm,
                    DesignTokens.spacingLg,
                    DesignTokens.spacingXxl,
                  ),
                  children: [
                    if (continueBook != null) ...[
                      _ContinueReadingCard(
                        book: continueBook,
                        onTap: () => _continueReading(continueBook),
                      ),
                      const SizedBox(height: DesignTokens.spacingLg),
                    ],
                    Text(
                      '分类',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSubtitle,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacingMd),
                    _buildCategoryGrid(selected, categories, colorScheme),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme colorScheme) {
    final onSurfaceColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: DesignTokens.spacingLg,
        right: DesignTokens.spacingXs,
        bottom: DesignTokens.spacingSm,
      ),
      color: colorScheme.surface,
      child: SizedBox(
        height: DesignTokens.tagBarHeight,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: DesignTokens.tagBarHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(DesignTokens.searchRadius),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: TextField(
                  readOnly: true,
                  canRequestFocus: false,
                  decoration: InputDecoration(
                    hintText: '搜索书名、作者',
                    hintStyle: TextStyle(
                      fontSize: DesignTokens.fontSummary,
                      color: secondaryTextColor,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingSm,
                      vertical: 0,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(
                    fontSize: DesignTokens.fontSummary,
                    color: onSurfaceColor,
                  ),
                  // 入口跳转到多书源聚合搜索页（SearchPage 自带输入与搜索）
                  onTap: _openSearch,
                ),
              ),
            ),
            Consumer<DiscoveryProvider>(
              builder: (context, provider, _) {
                final sources = _discoverableSources(provider.bookSources);
                if (sources.length <= 1) {
                  return const SizedBox(width: DesignTokens.spacingXs);
                }
                final selected = _resolveSelectedSource(sources);
                final label = selected?.bookSourceName ?? '书源';
                return PopupMenuButton<String>(
                  tooltip: '切换书源',
                  offset: const Offset(0, DesignTokens.topBarHeight),
                  onSelected: (url) {
                    setState(() => _selectedSourceUrl = url);
                    _persistDiscoverySourceChoice(url);
                  },
                  itemBuilder: (context) => sources
                      .map(
                        (s) => CheckedPopupMenuItem<String>(
                          value: s.bookSourceUrl,
                          checked: s.bookSourceUrl == selected?.bookSourceUrl,
                          child: Text(
                            s.bookSourceName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: DesignTokens.fontCaption,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    BookSource source,
    List<ExploreCategory> categories,
    ColorScheme colorScheme,
  ) {
    // 笔趣阁式分类墙：用 Wrap 保证长分类名完整换行显示、不被截断
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const gap = DesignTokens.spacingSm;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: categories.map((category) {
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
                child: InkWell(
                  onTap: () => _openExplore(source, category),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.panelRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingSm,
                      vertical: DesignTokens.spacingMd,
                    ),
                    child: Text(
                      category.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: DesignTokens.fontBody,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required ColorScheme colorScheme,
    String? actionText,
    VoidCallback? onAction,
    String? secondaryText,
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: DesignTokens.emptyIconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: DesignTokens.spacingLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: DesignTokens.spacingMd),
              FilledButton(
                onPressed: onAction,
                child: Text(actionText),
              ),
            ],
            if (secondaryText != null) ...[
              const SizedBox(height: DesignTokens.spacingMd),
              Text(
                secondaryText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: DesignTokens.fontCaption,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (secondaryActionText != null && onSecondaryAction != null)
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionText),
              ),
          ],
        ),
      ),
    );
  }
}

/// 「继续阅读」卡片
class _ContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ContinueReadingCard({
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chapterLabel = book.durChapterTitle.isNotEmpty
        ? book.durChapterTitle
        : '第${book.durChapterIndex + 1}章';

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingMd),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.actionRadius),
                child: SizedBox(
                  width: 52,
                  height: 70,
                  child: _buildCover(isDark),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续阅读',
                      style: TextStyle(
                        fontSize: DesignTokens.fontCaption,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesignTokens.fontSubtitle,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '读到：$chapterLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DesignTokens.fontCaption,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingMd,
                    vertical: DesignTokens.spacingSm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('继续'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(bool isDark) {
    // 走共享的 BookCover：它带防盗链请求头与加密封面解密，缺了这两样，
    // 同一本书的封面会「书架显示得出、这里显示不出」。
    return BookCover(
      book: book,
      isDark: isDark,
      width: 52,
      height: 70,
    );
  }
}
