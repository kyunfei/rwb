import 'dart:convert';

/// 策展书城：单本书条目（数据与 UI 分离，字段缺失时用空串兜底）。
class CuratedBook {
  final String id;
  final String name;
  final String author;
  final String category;
  final String intro;
  final String coverUrl;

  const CuratedBook({
    required this.id,
    required this.name,
    required this.author,
    this.category = '',
    this.intro = '',
    this.coverUrl = '',
  });

  bool get hasCover => coverUrl.trim().isNotEmpty;
}

/// 轮播位：指向一本书 + 安利文案。
class CuratedBanner {
  final String id;
  final String tagline;
  final String bookId;

  const CuratedBanner({
    required this.id,
    required this.tagline,
    required this.bookId,
  });
}

/// 圆形快捷入口：指向某个书单。
class CuratedShortcut {
  final String id;
  final String title;
  final String icon;
  final String listId;

  const CuratedShortcut({
    required this.id,
    required this.title,
    required this.icon,
    required this.listId,
  });
}

/// 精选页区块（如「热门连载」）。
class CuratedFeaturedSection {
  final String id;
  final String title;
  final List<String> bookIds;

  const CuratedFeaturedSection({
    required this.id,
    required this.title,
    required this.bookIds,
  });
}

/// 分类。
class CuratedCategory {
  final String id;
  final String title;
  final List<String> bookIds;

  const CuratedCategory({
    required this.id,
    required this.title,
    required this.bookIds,
  });
}

/// 榜单。
class CuratedRanking {
  final String id;
  final String title;
  final List<String> bookIds;

  const CuratedRanking({
    required this.id,
    required this.title,
    required this.bookIds,
  });
}

/// 书单（主题合集）。
class CuratedBookList {
  final String id;
  final String title;
  final String subtitle;
  final List<String> bookIds;

  const CuratedBookList({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.bookIds,
  });
}

/// 完整策展清单。
class CuratedBookstore {
  final int version;
  final List<CuratedBanner> banners;
  final List<CuratedShortcut> shortcuts;
  final List<CuratedFeaturedSection> featuredSections;
  final List<CuratedCategory> categories;
  final List<CuratedRanking> rankings;
  final List<CuratedBookList> lists;
  final Map<String, CuratedBook> booksById;

  const CuratedBookstore({
    this.version = 1,
    this.banners = const [],
    this.shortcuts = const [],
    this.featuredSections = const [],
    this.categories = const [],
    this.rankings = const [],
    this.lists = const [],
    this.booksById = const {},
  });

  static const empty = CuratedBookstore();

  bool get isEmpty =>
      banners.isEmpty &&
      shortcuts.isEmpty &&
      featuredSections.isEmpty &&
      categories.isEmpty &&
      rankings.isEmpty &&
      lists.isEmpty &&
      booksById.isEmpty;

  CuratedBook? bookById(String? id) {
    if (id == null || id.isEmpty) return null;
    return booksById[id];
  }

  List<CuratedBook> booksForIds(List<String> ids) {
    final out = <CuratedBook>[];
    for (final id in ids) {
      final book = booksById[id];
      if (book != null) out.add(book);
    }
    return out;
  }

  CuratedBookList? listById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final list in lists) {
      if (list.id == id) return list;
    }
    return null;
  }
}

/// 解析策展 JSON（容错：字段缺失/类型错误不抛，返回尽可能完整的结构）。
CuratedBookstore parseCuratedBookstore(Object? raw) {
  final root = _asMap(raw);
  if (root == null) return CuratedBookstore.empty;

  final books = <String, CuratedBook>{};
  final booksRaw = root['books'];
  if (booksRaw is List) {
    for (final item in booksRaw) {
      final book = _parseBook(item);
      if (book != null && book.id.isNotEmpty && book.name.isNotEmpty) {
        books[book.id] = book;
      }
    }
  }

  return CuratedBookstore(
    version: _asInt(root['version'], fallback: 1),
    banners: _parseList(root['banners'], _parseBanner),
    shortcuts: _parseList(root['shortcuts'], _parseShortcut),
    featuredSections:
        _parseList(root['featuredSections'], _parseFeaturedSection),
    categories: _parseList(root['categories'], _parseCategory),
    rankings: _parseList(root['rankings'], _parseRanking),
    lists: _parseList(root['lists'], _parseBookList),
    booksById: books,
  );
}

/// 从 JSON 字符串解析；非法 JSON 返回 empty，不抛。
CuratedBookstore parseCuratedBookstoreJson(String source) {
  try {
    return parseCuratedBookstore(jsonDecode(source));
  } catch (_) {
    return CuratedBookstore.empty;
  }
}

CuratedBook? _parseBook(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  final name = _asString(m['name']);
  if (id.isEmpty || name.isEmpty) return null;
  return CuratedBook(
    id: id,
    name: name,
    author: _asString(m['author']),
    category: _asString(m['category']),
    intro: _asString(m['intro']),
    coverUrl: _asString(m['coverUrl']),
  );
}

CuratedBanner? _parseBanner(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  final bookId = _asString(m['bookId']);
  if (id.isEmpty || bookId.isEmpty) return null;
  return CuratedBanner(
    id: id,
    tagline: _asString(m['tagline']),
    bookId: bookId,
  );
}

CuratedShortcut? _parseShortcut(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  final listId = _asString(m['listId']);
  if (id.isEmpty || listId.isEmpty) return null;
  return CuratedShortcut(
    id: id,
    title: _asString(m['title'], fallback: '入口'),
    icon: _asString(m['icon'], fallback: 'auto_stories'),
    listId: listId,
  );
}

CuratedFeaturedSection? _parseFeaturedSection(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  if (id.isEmpty) return null;
  return CuratedFeaturedSection(
    id: id,
    title: _asString(m['title'], fallback: '精选'),
    bookIds: _asStringList(m['bookIds']),
  );
}

CuratedCategory? _parseCategory(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  if (id.isEmpty) return null;
  return CuratedCategory(
    id: id,
    title: _asString(m['title'], fallback: '分类'),
    bookIds: _asStringList(m['bookIds']),
  );
}

CuratedRanking? _parseRanking(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  if (id.isEmpty) return null;
  return CuratedRanking(
    id: id,
    title: _asString(m['title'], fallback: '榜单'),
    bookIds: _asStringList(m['bookIds']),
  );
}

CuratedBookList? _parseBookList(Object? raw) {
  final m = _asMap(raw);
  if (m == null) return null;
  final id = _asString(m['id']);
  if (id.isEmpty) return null;
  return CuratedBookList(
    id: id,
    title: _asString(m['title'], fallback: '书单'),
    subtitle: _asString(m['subtitle']),
    bookIds: _asStringList(m['bookIds']),
  );
}

List<T> _parseList<T>(Object? raw, T? Function(Object?) parseItem) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    final parsed = parseItem(item);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

Map<String, dynamic>? _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  return fallback;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _asStringList(Object? raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final item in raw) {
    final s = _asString(item);
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}
