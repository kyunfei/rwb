import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/services/discovery_source_selection_logic.dart';

BookSource _src(
  String url,
  String name, {
  int customOrder = 0,
  String? group,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    bookSourceGroup: group,
    customOrder: customOrder,
  );
}

void main() {
  group('bookSourceLooksChinese', () {
    test('名称含汉字', () {
      expect(bookSourceLooksChinese(_src('u', '中文文库')), isTrue);
    });

    test('仅英文名称', () {
      expect(bookSourceLooksChinese(_src('u', 'Project Gutenberg')), isFalse);
    });

    test('分组含汉字', () {
      expect(
        bookSourceLooksChinese(_src('u', 'Mirror', group: '镜像·中文')),
        isTrue,
      );
    });
  });

  group('resolveDiscoverySelectedSourceUrl', () {
    test('空列表 → null', () {
      expect(
        resolveDiscoverySelectedSourceUrl(discoverable: [], lastSelectedUrl: 'x'),
        isNull,
      );
    });

    test('有上次选择且在列表中', () {
      final sources = [
        _src('en', 'English Wikisource'),
        _src('zh', '某中文源'),
      ];
      expect(
        resolveDiscoverySelectedSourceUrl(
          discoverable: sources,
          lastSelectedUrl: 'en',
        ),
        'en',
      );
    });

    test('上次选择的源已被删 → 回退到中文默认', () {
      final sources = [
        _src('en', 'English Wikisource'),
        _src('zh', '皮皮小说网'),
      ];
      expect(
        resolveDiscoverySelectedSourceUrl(
          discoverable: sources,
          lastSelectedUrl: 'removed',
        ),
        'zh',
      );
    });

    test('有置顶源（customOrder 最小且为负）优先于中文启发式', () {
      final sources = [
        _src('zh', '中文维基文库'),
        _src('en-pinned', 'English Wikisource', customOrder: -2),
      ];
      expect(
        resolveDiscoverySelectedSourceUrl(discoverable: sources),
        'en-pinned',
      );
    });

    test('仅英文源 → 列表首个', () {
      final sources = [
        _src('a', 'English Wikisource'),
        _src('b', 'Project Gutenberg'),
      ];
      expect(
        resolveDiscoverySelectedSourceUrl(discoverable: sources),
        'a',
      );
    });

    test('中英文共存且无上次选择、无置顶 → 首个中文向源', () {
      final sources = [
        _src('en', 'English Wikisource'),
        _src('g', 'Project Gutenberg'),
        _src('zh', '中文维基文库'),
        _src('pp', '皮皮小说网'),
      ];
      expect(
        resolveDiscoverySelectedSourceUrl(discoverable: sources),
        'zh',
      );
    });

    test('上次选择优先于置顶与中文', () {
      final sources = [
        _src('zh', '中文维基文库', customOrder: -5),
        _src('pick', 'Project Gutenberg'),
      ];
      expect(
        resolveDiscoverySelectedSourceUrl(
          discoverable: sources,
          lastSelectedUrl: 'pick',
        ),
        'pick',
      );
    });
  });
}
