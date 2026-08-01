import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/search/search_text_normalizer.dart';
import 'package:mr/services/search/search_ranker.dart';
import 'package:mr/services/search/search_aggregator.dart';

void main() {
  group('SearchTextNormalizer', () {
    test('strips wrap chars and whitespace', () {
      expect(SearchTextNormalizer.normalize('《斗 破 苍 穹》'), '斗破苍穹');
      expect(SearchTextNormalizer.normalize('「一念永恒」'), '一念永恒');
      expect(SearchTextNormalizer.normalize('[修真聊天群]'), '修真聊天群');
    });

    test('unifies full-width and half-width', () {
      expect(
        SearchTextNormalizer.normalize('ＡＢＣ１２３'),
        SearchTextNormalizer.normalize('ABC123'),
      );
      expect(
        SearchTextNormalizer.normalize('作者　名字'),
        SearchTextNormalizer.normalize('作者名字'),
      );
    });

    test('case insensitive english', () {
      expect(
        SearchTextNormalizer.normalize('Harry Potter'),
        SearchTextNormalizer.normalize('harry potter'),
      );
    });

    test('dedupeKey joins name and author', () {
      final a = SearchTextNormalizer.dedupeKey('《三体》', '刘 慈欣');
      final b = SearchTextNormalizer.dedupeKey('三体', '刘慈欣');
      expect(a, b);
      expect(
        SearchTextNormalizer.dedupeKey('三体', '刘慈欣'),
        isNot(SearchTextNormalizer.dedupeKey('三体', '其他')),
      );
    });
  });

  group('SearchRanker', () {
    test('match tier exact > prefix > contains > none', () {
      expect(SearchRanker.matchTier('三体', '三体'), SearchRanker.matchExact);
      expect(SearchRanker.matchTier('三体', '三体II'), SearchRanker.matchPrefix);
      expect(SearchRanker.matchTier('三体', '我读三体'), SearchRanker.matchContains);
      expect(SearchRanker.matchTier('三体', '球状闪电'), SearchRanker.matchNone);
    });

    test('score prefers better match then more origins then weight', () {
      final exactOne = SearchRanker.score(
        keyword: '三体',
        name: '三体',
        originCount: 1,
        sourceWeight: 0,
      );
      final containsMany = SearchRanker.score(
        keyword: '三体',
        name: '关于三体的书',
        originCount: 5,
        sourceWeight: 100,
      );
      expect(exactOne, greaterThan(containsMany));

      final multi = SearchRanker.score(
        keyword: '三体',
        name: '三体',
        originCount: 3,
        sourceWeight: 1,
      );
      final singleHeavy = SearchRanker.score(
        keyword: '三体',
        name: '三体',
        originCount: 1,
        sourceWeight: 999,
      );
      expect(multi, greaterThan(singleHeavy));
    });

    test('sortResults orders by score desc', () {
      final list = <Map<String, dynamic>>[
        {'name': 'xx三体xx', 'originCount': 1, 'sourceWeight': 0},
        {'name': '三体', 'originCount': 1, 'sourceWeight': 0},
        {'name': '三体II', 'originCount': 2, 'sourceWeight': 0},
      ];
      SearchRanker.sortResults(list, keyword: '三体');
      expect(list[0]['name'], '三体');
      expect(list[1]['name'], '三体II');
      expect(list[2]['name'], 'xx三体xx');
    });
  });

  group('SearchAggregator', () {
    test('merges same book across sources after normalize', () {
      final agg = SearchAggregator(keyword: '三体');
      agg.add(
        {'name': '《三体》', 'author': '刘慈欣', 'bookUrl': 'http://a/1', 'coverUrl': ''},
        sourceUrl: 'http://src-a',
        sourceName: '源A',
        sourceWeight: 1,
      );
      agg.add(
        {
          'name': '三体',
          'author': '刘 慈欣',
          'bookUrl': 'http://b/1',
          'coverUrl': 'http://cover',
        },
        sourceUrl: 'http://src-b',
        sourceName: '源B',
        sourceWeight: 10,
      );
      expect(agg.results, hasLength(1));
      final item = agg.results.first;
      expect(item['originCount'], 2);
      expect((item['origins'] as List), hasLength(2));
      expect(item['coverUrl'], 'http://cover');
      // higher weight becomes primary
      expect(item['sourceUrl'], 'http://src-b');
      expect(item['sourceName'], '源B');
    });

    test('different books stay separate', () {
      final agg = SearchAggregator(keyword: '三');
      agg.add(
        {'name': '三体', 'author': '刘慈欣', 'bookUrl': 'a'},
        sourceUrl: 's1',
        sourceName: 'S1',
      );
      agg.add(
        {'name': '三生三世', 'author': '唐七', 'bookUrl': 'b'},
        sourceUrl: 's2',
        sourceName: 'S2',
      );
      expect(agg.results, hasLength(2));
    });

    test('resort puts exact match first', () {
      final agg = SearchAggregator(keyword: '斗破苍穹');
      agg.add(
        {'name': '斗破苍穹续', 'author': '天蚕土豆', 'bookUrl': 'a'},
        sourceUrl: 's1',
        sourceName: 'S1',
        sourceWeight: 100,
      );
      agg.add(
        {'name': '斗破苍穹', 'author': '天蚕土豆', 'bookUrl': 'b'},
        sourceUrl: 's2',
        sourceName: 'S2',
        sourceWeight: 0,
      );
      agg.resort();
      expect(agg.results.first['name'], '斗破苍穹');
    });
  });
}
