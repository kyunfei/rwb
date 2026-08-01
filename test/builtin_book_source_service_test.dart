import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/services/builtin_book_source_service.dart';

class MemoryBuiltinSourceSeedStore implements BuiltinSourceSeedStore {
  MemoryBuiltinSourceSeedStore({
    this.isInitialized = true,
    Map<String, dynamic>? settings,
    Map<String, Map<String, dynamic>>? sources,
  })  : settings = settings ?? <String, dynamic>{},
        sources = sources ?? <String, Map<String, dynamic>>{};

  @override
  bool isInitialized;

  final Map<String, dynamic> settings;
  final Map<String, Map<String, dynamic>> sources;

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) =>
      settings.containsKey(key) ? settings[key] : defaultValue;

  @override
  Future<void> setSetting(String key, dynamic value) async {
    settings[key] = value;
  }

  @override
  Map<String, dynamic>? getBookSource(String sourceUrl) => sources[sourceUrl];

  @override
  Future<void> saveBookSource(Map<String, dynamic> sourceData) async {
    final url = sourceData['bookSourceUrl'] as String? ?? '';
    if (url.isEmpty) return;
    sources[url] = Map<String, dynamic>.from(sourceData);
  }
}

void main() {
  BookSource source(String url, String name) => BookSource(
        bookSourceUrl: url,
        bookSourceName: name,
      );

  Future<List<BookSource>> loadFixture() async => [
        source('https://zh.wikisource.org', '中文维基文库'),
        source('https://www.ppxsw.co', '皮皮小说网'),
        source('https://www.gutenberg.org', 'Project Gutenberg'),
        source('https://en.wikisource.org', 'English Wikisource'),
        source('https://standardebooks.org', 'Standard Ebooks'),
      ];

  group('ensureBuiltinSourcesSeeded', () {
    test('首次注入写入全部内置源并打上 v3 标记', () async {
      final store = MemoryBuiltinSourceSeedStore();
      final added = await BuiltinBookSourceService.ensureBuiltinSourcesSeeded(
        store: store,
        loadSources: loadFixture,
      );
      expect(added, 5);
      expect(store.sources.keys, contains('https://zh.wikisource.org'));
      expect(store.sources.keys, contains('https://www.ppxsw.co'));
      expect(
        store.getSetting(BuiltinBookSourceService.seededFlagKey),
        isTrue,
      );
    });

    test('已打 v3 标记时幂等，不再写入', () async {
      final store = MemoryBuiltinSourceSeedStore(
        settings: {BuiltinBookSourceService.seededFlagKey: true},
      );
      final added = await BuiltinBookSourceService.ensureBuiltinSourcesSeeded(
        store: store,
        loadSources: loadFixture,
      );
      expect(added, 0);
      expect(store.sources, isEmpty);
    });

    test('仅有旧版 v2 标记时仍会补跑 v3（可补中文维基文库）', () async {
      final store = MemoryBuiltinSourceSeedStore(
        settings: {
          BuiltinBookSourceService.previousSeededFlagKey: true,
        },
        sources: {
          'https://www.ppxsw.co':
              source('https://www.ppxsw.co', '皮皮小说网').toJson(),
          'https://www.gutenberg.org':
              source('https://www.gutenberg.org', 'Project Gutenberg').toJson(),
          'https://en.wikisource.org':
              source('https://en.wikisource.org', 'English Wikisource').toJson(),
          'https://standardebooks.org':
              source('https://standardebooks.org', 'Standard Ebooks').toJson(),
        },
      );
      final added = await BuiltinBookSourceService.ensureBuiltinSourcesSeeded(
        store: store,
        loadSources: loadFixture,
      );
      expect(added, 1);
      expect(
        store.sources['https://zh.wikisource.org']?['bookSourceName'],
        '中文维基文库',
      );
      expect(
        store.getSetting(BuiltinBookSourceService.seededFlagKey),
        isTrue,
      );
    });

    test('仅有旧版 v1 标记时仍会补跑（可补中文源）', () async {
      final store = MemoryBuiltinSourceSeedStore(
        settings: {BuiltinBookSourceService.legacySeededFlagKey: true},
        sources: {
          'https://www.gutenberg.org':
              source('https://www.gutenberg.org', 'Project Gutenberg').toJson(),
          'https://en.wikisource.org':
              source('https://en.wikisource.org', 'English Wikisource').toJson(),
          'https://standardebooks.org':
              source('https://standardebooks.org', 'Standard Ebooks').toJson(),
        },
      );
      final added = await BuiltinBookSourceService.ensureBuiltinSourcesSeeded(
        store: store,
        loadSources: loadFixture,
      );
      expect(added, 2);
      expect(store.sources['https://www.ppxsw.co']?['bookSourceName'], '皮皮小说网');
      expect(
        store.sources['https://zh.wikisource.org']?['bookSourceName'],
        '中文维基文库',
      );
      expect(
        store.getSetting(BuiltinBookSourceService.seededFlagKey),
        isTrue,
      );
    });

    test('不覆盖用户已修改的同 URL 源', () async {
      final store = MemoryBuiltinSourceSeedStore(
        sources: {
          'https://www.ppxsw.co':
              source('https://www.ppxsw.co', '用户改过的名字').toJson(),
        },
      );
      final added = await BuiltinBookSourceService.ensureBuiltinSourcesSeeded(
        store: store,
        loadSources: loadFixture,
      );
      expect(added, 4);
      expect(
        store.sources['https://www.ppxsw.co']?['bookSourceName'],
        '用户改过的名字',
      );
    });

    test('存储未初始化时直接返回 0', () async {
      final store = MemoryBuiltinSourceSeedStore(isInitialized: false);
      final added = await BuiltinBookSourceService.ensureBuiltinSourcesSeeded(
        store: store,
        loadSources: loadFixture,
      );
      expect(added, 0);
      expect(
        store.getSetting(
          BuiltinBookSourceService.seededFlagKey,
          defaultValue: false,
        ),
        isFalse,
      );
    });
  });

  group('assetPaths', () {
    test('包含中文维基文库、中文示例源与三个英文公有领域源', () {
      expect(
        BuiltinBookSourceService.assetPaths,
        contains('assets/book_sources/chinese_wikisource.json'),
      );
      expect(
        BuiltinBookSourceService.assetPaths,
        contains('assets/book_sources/ppxsw.json'),
      );
      expect(BuiltinBookSourceService.assetPaths, hasLength(5));
    });
  });
}
