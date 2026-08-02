import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../models/curated_bookstore.dart';
import '../../providers/bookshelf_provider.dart';
import '../../providers/curated_bookstore_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/bookstore/curated_book_opener.dart';
import '../../services/bookstore/curated_match.dart';
import '../../utils/continue_reading.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/book_cover.dart';
import 'curated_bookstore_widgets.dart';

/// 书城页：笔趣阁式「精选 / 分类 / 榜单 / 书单」，内容由本地策展清单驱动。
///
/// 点击书籍走多源搜索拿真数据；保留顶部搜索框与「继续阅读」。
class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tabController;
  final CuratedBookOpener _opener = CuratedBookOpener();
  bool _openingBook = false;

  int _categoryIndex = 0;
  int _rankingIndex = 0;
  String? _focusedListId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      // 离开「书单」详情时清焦点，回到书单列表
      if (_tabController.index != 3) {
        setState(() => _focusedListId = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CuratedBookstoreProvider>().load();
      context.read<DiscoveryProvider>().loadBookSources();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.pushNamed(context, AppRoutes.search);
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
        'resumeProgress': true,
      },
    );
    if (!mounted) return;
    await context.read<BookshelfProvider>().loadBooks();
  }

  Future<void> _onCuratedBookTap(CuratedBook book) async {
    if (_openingBook) return;
    setState(() => _openingBook = true);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: DesignTokens.spacingLg),
                Expanded(
                  child: Text('正在多源搜索「${book.name}」…'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final sources = context.read<DiscoveryProvider>().bookSources;
      final result = await _opener.open(book, sources: sources);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关 loading

      if (result.isError ||
          result.decision.action == CuratedOpenAction.notFound) {
        await _showNotFoundDialog(
          book,
          result.errorMessage ??
              '所有书源都没有找到「${book.name}」，请稍后重试或手动搜索。',
        );
        return;
      }

      if (result.decision.action == CuratedOpenAction.openDetail &&
          result.decision.bestResult != null) {
        final bookData =
            CuratedBookOpener.toDetailBookData(result.decision.bestResult!);
        await Navigator.pushNamed(
          context,
          AppRoutes.detail,
          arguments: {
            'bookUrl': bookData['bookUrl'],
            'bookData': bookData,
          },
        );
        return;
      }

      // 不确定 / 多候选 → 打开现有搜索页让用户选
      await Navigator.pushNamed(
        context,
        AppRoutes.search,
        arguments: {'keyword': result.decision.searchKeyword},
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showNotFoundDialog(
        book,
        '搜索「${book.name}」时出错，请检查网络后重试。',
      );
    } finally {
      if (mounted) setState(() => _openingBook = false);
    }
  }

  Future<void> _showNotFoundDialog(CuratedBook book, String message) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未找到书籍'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              Navigator.pushNamed(
                context,
                AppRoutes.search,
                arguments: {
                  'keyword': buildCuratedSearchKeyword(book.name, book.author),
                },
              );
            },
            child: const Text('手动搜索'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
    if (retry == true && mounted) {
      await _onCuratedBookTap(book);
    }
  }

  void _openShortcut(CuratedShortcut shortcut) {
    setState(() {
      _focusedListId = shortcut.listId;
      _tabController.animateTo(3);
    });
  }

  void _requestCoversFor(Iterable<CuratedBook> books) {
    final curated = context.read<CuratedBookstoreProvider>();
    final sources = context.read<DiscoveryProvider>().bookSources;
    curated.requestCovers(books, sources: sources);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(colorScheme),
          Material(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor:
                  colorScheme.onSurface.withValues(alpha: 0.55),
              indicatorColor: colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: DesignTokens.fontBody,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: DesignTokens.fontBody,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: '精选'),
                Tab(text: '分类'),
                Tab(text: '榜单'),
                Tab(text: '书单'),
              ],
            ),
          ),
          Expanded(
            child: Consumer3<CuratedBookstoreProvider, BookshelfProvider,
                DiscoveryProvider>(
              builder: (context, curated, bookshelf, discovery, _) {
                if (curated.isLoading && !curated.isLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                final continueBook =
                    pickLatestReadingBook(bookshelf.allBooks);
                final data = curated.data;

                if (curated.loadError != null && data.isEmpty) {
                  return _buildFatalEmpty(
                    colorScheme,
                    curated.loadError!,
                    onRetry: () => curated.load(force: true),
                  );
                }

                return Column(
                  children: [
                    if (continueBook != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DesignTokens.spacingLg,
                          DesignTokens.spacingSm,
                          DesignTokens.spacingLg,
                          0,
                        ),
                        child: _ContinueReadingCard(
                          book: continueBook,
                          onTap: () => _continueReading(continueBook),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeaturedTab(curated, data),
                          _buildCategoryTab(curated, data),
                          _buildRankingTab(curated, data),
                          _buildListsTab(curated, data),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFatalEmpty(
    ColorScheme colorScheme,
    String message, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: DesignTokens.emptyIconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: DesignTokens.spacingLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
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
        right: DesignTokens.spacingLg,
        bottom: DesignTokens.spacingSm,
      ),
      color: colorScheme.surface,
      child: SizedBox(
        height: DesignTokens.tagBarHeight,
        child: Container(
          height: DesignTokens.tagBarHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(DesignTokens.searchRadius),
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
            onTap: _openSearch,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedTab(
    CuratedBookstoreProvider curated,
    CuratedBookstore data,
  ) {
    final sections = data.featuredSections;
    final booksToCover = <CuratedBook>[
      for (final b in data.banners)
        if (data.bookById(b.bookId) != null) data.bookById(b.bookId)!,
      for (final s in sections) ...data.booksForIds(s.bookIds),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestCoversFor(booksToCover);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingLg,
        DesignTokens.spacingMd,
        DesignTokens.spacingLg,
        DesignTokens.spacingXxl,
      ),
      children: [
        CuratedBannerCarousel(
          banners: data.banners,
          data: data,
          coverUrlFor: curated.coverUrlFor,
          onBookTap: _onCuratedBookTap,
        ),
        if (data.shortcuts.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.spacingLg),
          CuratedShortcutRow(
            shortcuts: data.shortcuts,
            onTap: _openShortcut,
          ),
        ],
        if (sections.isEmpty && data.banners.isEmpty)
          const CuratedEmptyHint(message: '精选内容暂未配置，稍后再来看看'),
        for (final section in sections) ...[
          const SizedBox(height: DesignTokens.spacingXl),
          Text(
            section.title,
            style: TextStyle(
              fontSize: DesignTokens.fontSubtitle,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Builder(
            builder: (context) {
              final books = data.booksForIds(section.bookIds);
              if (books.isEmpty) {
                return const CuratedEmptyHint(message: '该栏目暂无书籍');
              }
              return Column(
                children: [
                  for (final book in books)
                    CuratedBookListTile(
                      book: book,
                      coverUrl: curated.coverUrlFor(book),
                      onTap: () => _onCuratedBookTap(book),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryTab(
    CuratedBookstoreProvider curated,
    CuratedBookstore data,
  ) {
    final cats = data.categories;
    if (cats.isEmpty) {
      return const CuratedEmptyHint(message: '暂无分类，策展清单更新后即可浏览');
    }
    final safeIndex = _categoryIndex.clamp(0, cats.length - 1);
    final selected = cats[safeIndex];
    final books = data.booksForIds(selected.bookIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestCoversFor(books);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.spacingLg,
            DesignTokens.spacingMd,
            DesignTokens.spacingLg,
            DesignTokens.spacingSm,
          ),
          child: CuratedChipBar(
            labels: cats.map((c) => c.title).toList(),
            selectedIndex: safeIndex,
            onSelected: (i) => setState(() => _categoryIndex = i),
          ),
        ),
        Expanded(
          child: books.isEmpty
              ? const CuratedEmptyHint(message: '该分类下暂无书籍')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spacingLg,
                    0,
                    DesignTokens.spacingLg,
                    DesignTokens.spacingXxl,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, i) {
                    final book = books[i];
                    return CuratedBookListTile(
                      book: book,
                      coverUrl: curated.coverUrlFor(book),
                      onTap: () => _onCuratedBookTap(book),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRankingTab(
    CuratedBookstoreProvider curated,
    CuratedBookstore data,
  ) {
    final ranks = data.rankings;
    if (ranks.isEmpty) {
      return const CuratedEmptyHint(message: '暂无榜单');
    }
    final safeIndex = _rankingIndex.clamp(0, ranks.length - 1);
    final selected = ranks[safeIndex];
    final books = data.booksForIds(selected.bookIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestCoversFor(books);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.spacingLg,
            DesignTokens.spacingMd,
            DesignTokens.spacingLg,
            DesignTokens.spacingSm,
          ),
          child: CuratedChipBar(
            labels: ranks.map((r) => r.title).toList(),
            selectedIndex: safeIndex,
            onSelected: (i) => setState(() => _rankingIndex = i),
          ),
        ),
        Expanded(
          child: books.isEmpty
              ? const CuratedEmptyHint(message: '该榜单暂无书籍')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spacingLg,
                    0,
                    DesignTokens.spacingLg,
                    DesignTokens.spacingXxl,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, i) {
                    final book = books[i];
                    return CuratedBookListTile(
                      book: book,
                      coverUrl: curated.coverUrlFor(book),
                      rank: i + 1,
                      onTap: () => _onCuratedBookTap(book),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListsTab(
    CuratedBookstoreProvider curated,
    CuratedBookstore data,
  ) {
    final focused = data.listById(_focusedListId);
    if (focused != null) {
      final books = data.booksForIds(focused.bookIds);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _requestCoversFor(books);
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.spacingSm,
              DesignTokens.spacingXs,
              DesignTokens.spacingLg,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回书单列表',
                  onPressed: () => setState(() => _focusedListId = null),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        focused.title,
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSubtitle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (focused.subtitle.isNotEmpty)
                        Text(
                          focused.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: DesignTokens.fontCaption,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? const CuratedEmptyHint(message: '该书单暂无书籍')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      DesignTokens.spacingLg,
                      DesignTokens.spacingSm,
                      DesignTokens.spacingLg,
                      DesignTokens.spacingXxl,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, i) {
                      final book = books[i];
                      return CuratedBookListTile(
                        book: book,
                        coverUrl: curated.coverUrlFor(book),
                        onTap: () => _onCuratedBookTap(book),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    final lists = data.lists;
    if (lists.isEmpty) {
      return const CuratedEmptyHint(message: '暂无书单');
    }

    final previewAll = <CuratedBook>[];
    for (final list in lists) {
      previewAll.addAll(data.booksForIds(list.bookIds).take(4));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestCoversFor(previewAll);
    });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingLg,
        DesignTokens.spacingMd,
        DesignTokens.spacingLg,
        DesignTokens.spacingXxl,
      ),
      itemCount: lists.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: DesignTokens.spacingMd),
      itemBuilder: (context, i) {
        final list = lists[i];
        return CuratedListCard(
          list: list,
          previewBooks: data.booksForIds(list.bookIds),
          coverUrlFor: curated.coverUrlFor,
          onTap: () => setState(() => _focusedListId = list.id),
        );
      },
    );
  }
}

/// 「继续阅读」卡片（真机已验证，保持原交互）。
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
                  child: BookCover(
                    book: book,
                    isDark: isDark,
                    width: 52,
                    height: 70,
                  ),
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
}
