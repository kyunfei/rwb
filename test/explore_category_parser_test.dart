import 'package:flutter_test/flutter_test.dart';
import 'package:mr/utils/explore_category_parser.dart';

void main() {
  group('parseExploreKinds', () {
    test('空输入 → 空列表', () {
      expect(parseExploreKinds(null), isEmpty);
      expect(parseExploreKinds(''), isEmpty);
    });

    test(':: 与 && 格式', () {
      final cats = parseExploreKinds(
        '玄幻修真::https://a.com/xuan&&都市小说::https://a.com/du',
      );
      expect(cats.length, 2);
      expect(cats[0].title, '玄幻修真');
      expect(cats[0].url, 'https://a.com/xuan');
      expect(cats[1].title, '都市小说');
    });

    test('JSON 列表格式', () {
      final cats = parseExploreKinds(
        '[{"title":"言情","url":"https://a.com/yq"},{"title":"历史","url":"https://a.com/ls"}]',
      );
      expect(cats.map((c) => c.title).toList(), ['言情', '历史']);
    });
  });

  group('flattenExploreCategories', () {
    test('展平带 children 的分类', () {
      final nested = [
        const ExploreCategory(
          title: '分组',
          url: '',
          children: [
            ExploreCategory(title: '子1', url: 'https://a.com/1'),
            ExploreCategory(title: '子2', url: 'https://a.com/2'),
          ],
        ),
        const ExploreCategory(title: '直接', url: 'https://a.com/d'),
      ];
      final flat = flattenExploreCategories(nested);
      expect(flat.map((c) => c.title).toList(), ['子1', '子2', '直接']);
    });
  });
}
