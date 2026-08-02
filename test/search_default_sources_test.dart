import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/providers/search_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

BookSource _src(
  String url, {
  int weight = 0,
  int respondTime = 180000,
  int customOrder = 0,
}) =>
    BookSource(
      bookSourceUrl: url,
      bookSourceName: url,
      searchUrl: '$url/search?q={{key}}',
      weight: weight,
      respondTime: respondTime,
      customOrder: customOrder,
    );

void main() {
  // 选择改动会落 prefs，测试里给个内存实现，顺带让持久化分支真正被走到
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pickDefaultSourceUrls', () {
    test('按 weight 降序挑选，而不是按存储顺序取前几个', () {
      // 存储顺序刻意与质量顺序相反：原实现的 take(5) 会全挑到最差的
      final sources = [
        _src('http://worst', weight: 0),
        _src('http://bad', weight: 10),
        _src('http://good', weight: 900),
        _src('http://best', weight: 2050),
      ];
      final picked = SearchProvider.pickDefaultSourceUrls(sources, limit: 2);
      expect(picked, ['http://best', 'http://good']);
    });

    test('weight 相同时按 respondTime 升序（快的优先）', () {
      final sources = [
        _src('http://slow', weight: 5, respondTime: 9000),
        _src('http://fast', weight: 5, respondTime: 300),
      ];
      final picked = SearchProvider.pickDefaultSourceUrls(sources, limit: 1);
      expect(picked, ['http://fast']);
    });

    test('weight 与 respondTime 都相同时按 customOrder（用户置顶）', () {
      final sources = [
        _src('http://later', weight: 1, respondTime: 100, customOrder: 5),
        _src('http://pinned', weight: 1, respondTime: 100, customOrder: -1),
      ];
      final picked = SearchProvider.pickDefaultSourceUrls(sources, limit: 1);
      expect(picked, ['http://pinned']);
    });

    test('源数少于上限时全取，不补空也不抛异常', () {
      final picked = SearchProvider.pickDefaultSourceUrls(
        [_src('http://only')],
        limit: 50,
      );
      expect(picked, ['http://only']);
    });

    test('空列表返回空，不抛异常', () {
      expect(SearchProvider.pickDefaultSourceUrls(const []), isEmpty);
    });

    test('limit 非法（0 或负数）时至少取一个，避免选不到源导致永远搜不出结果', () {
      final sources = [_src('http://a', weight: 9), _src('http://b')];
      expect(
        SearchProvider.pickDefaultSourceUrls(sources, limit: 0),
        ['http://a'],
      );
      expect(
        SearchProvider.pickDefaultSourceUrls(sources, limit: -3),
        ['http://a'],
      );
    });

    test('默认上限不至于把几百个源全选上', () {
      final many = List.generate(400, (i) => _src('http://s$i', weight: i));
      final picked = SearchProvider.pickDefaultSourceUrls(many);
      expect(picked.length, SearchProvider.defaultAutoSelectLimit);
      expect(picked.length, lessThan(many.length));
      // 头部应是 weight 最高的那些
      expect(picked.first, 'http://s399');
    });
  });

  group('单源路由不应冲掉多源选择', () {
    test('进入单源再返回，还原为进入前的选择而非全选', () {
      final sources = [
        _src('http://a', weight: 3),
        _src('http://b', weight: 2),
        _src('http://c', weight: 1),
      ];
      final provider = SearchProvider(initialSources: sources);
      provider.deselectAllSources();
      provider.toggleSourceSelection('http://b');
      expect(provider.selectedSourceUrls, {'http://b'});

      provider.selectSingleSource('http://c');
      expect(provider.selectedSourceUrls, {'http://c'});

      provider.restoreMultiSourceSelectionAfterSingleSourceRoute();
      expect(provider.selectedSourceUrls, {'http://b'},
          reason: '应还原用户原本只选 b 的选择，而不是把 a/b/c 全选上');
    });

    test('未进入过单源路由时，还原是空操作', () {
      final provider = SearchProvider(initialSources: [_src('http://a')]);
      provider.deselectAllSources();
      provider.restoreMultiSourceSelectionAfterSingleSourceRoute();
      expect(provider.selectedSourceUrls, isEmpty);
    });
  });

  test('选择会落盘：原先只活在内存里，冷启动就退回默认值', () async {
    final sources = [
      _src('http://a', weight: 3),
      _src('http://b', weight: 2),
    ];
    final provider = SearchProvider(initialSources: sources);
    provider.deselectAllSources();
    provider.toggleSourceSelection('http://b');
    // 落盘是即发即忘，给事件循环一次机会
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('searchSelectedSourceUrls'), ['http://b']);
  });
}
