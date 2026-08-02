import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/curated_bookstore.dart';
import 'package:mr/services/bookstore/curated_cover_resolver.dart';
import 'package:mr/services/bookstore/curated_match.dart';

void main() {
  group('parseCuratedBookstore', () {
    test('完整合法 JSON 能解析出各区块', () {
      final data = parseCuratedBookstore({
        'version': 1,
        'banners': [
          {'id': 'b1', 'tagline': '安利', 'bookId': 'book-1'},
        ],
        'shortcuts': [
          {
            'id': 's1',
            'title': '推荐',
            'icon': 'recommend',
            'listId': 'list-1',
          },
        ],
        'featuredSections': [
          {
            'id': 'sec',
            'title': '热门连载',
            'bookIds': ['book-1', 'missing'],
          },
        ],
        'categories': [
          {
            'id': 'cat',
            'title': '玄幻',
            'bookIds': ['book-1'],
          },
        ],
        'rankings': [
          {
            'id': 'rank',
            'title': '热门榜',
            'bookIds': ['book-1'],
          },
        ],
        'lists': [
          {
            'id': 'list-1',
            'title': '编辑力荐',
            'subtitle': '一句推荐语',
            'bookIds': ['book-1'],
          },
        ],
        'books': [
          {
            'id': 'book-1',
            'name': '凡人修仙传',
            'author': '忘语',
            'category': '仙侠',
            'intro': '简介',
          },
        ],
      });

      expect(data.version, 1);
      expect(data.banners, hasLength(1));
      expect(data.shortcuts.first.listId, 'list-1');
      expect(data.booksForIds(['book-1', 'missing']), hasLength(1));
      expect(data.listById('list-1')?.subtitle, '一句推荐语');
      expect(data.isEmpty, isFalse);
    });

    test('字段缺失 / 类型错误不崩，跳过坏项', () {
      final data = parseCuratedBookstore({
        'version': 'not-a-number',
        'banners': [
          {'id': 'ok', 'bookId': 'book-1', 'tagline': 123},
          {'id': '', 'bookId': 'x'},
          'not-a-map',
          null,
          {'id': 'no-book'},
        ],
        'shortcuts': [
          {'id': 's', 'listId': 'l'},
          {'title': '无 id'},
        ],
        'featuredSections': 'bad',
        'categories': [
          {'id': 'c', 'title': null, 'bookIds': 'not-list'},
        ],
        'rankings': [],
        'lists': [
          {'id': 'l', 'title': true, 'bookIds': [1, 'book-1', null]},
        ],
        'books': [
          {'id': 'book-1', 'name': '有名', 'author': null},
          {'id': 'no-name'},
          {'name': '无 id'},
          42,
        ],
      });

      expect(data.version, 1);
      expect(data.banners, hasLength(1));
      expect(data.banners.first.tagline, '123');
      expect(data.shortcuts, hasLength(1));
      expect(data.featuredSections, isEmpty);
      expect(data.categories, hasLength(1));
      expect(data.categories.first.bookIds, isEmpty);
      // 数字会被 toString 成 '1'，仍不崩；坏项 null 被跳过
      expect(data.lists.first.bookIds, ['1', 'book-1']);
      expect(data.booksById.keys, ['book-1']);
      expect(data.booksById['book-1']!.author, '');
    });

    test('root 非 map / 非法 JSON 字符串 → empty', () {
      expect(parseCuratedBookstore(null).isEmpty, isTrue);
      expect(parseCuratedBookstore('x').isEmpty, isTrue);
      expect(parseCuratedBookstoreJson('{').isEmpty, isTrue);
      expect(parseCuratedBookstoreJson('[]').isEmpty, isTrue);
    });

    test('列表全空时 isEmpty 为 true，booksForIds 返回空', () {
      final data = parseCuratedBookstore({
        'books': [],
        'categories': [],
      });
      expect(data.isEmpty, isTrue);
      expect(data.booksForIds(['a']), isEmpty);
      expect(data.bookById('a'), isNull);
      expect(data.listById('a'), isNull);
    });
  });

  group('scoreCuratedMatch / decideCuratedOpen', () {
    test('书名+作者完全匹配', () {
      final score = scoreCuratedMatch(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        resultName: '《凡人修仙传》',
        resultAuthor: '忘 语',
      );
      expect(score.kind, CuratedMatchKind.exactNameAndAuthor);
      expect(score.isHighConfidence, isTrue);

      final decision = decideCuratedOpen(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        results: [
          {'name': '凡人修仙传', 'author': '忘语', 'bookUrl': 'u1'},
          {'name': '凡人修仙传外传', 'author': '他人', 'bookUrl': 'u2'},
        ],
      );
      expect(decision.action, CuratedOpenAction.openDetail);
      expect(decision.bestResult?['bookUrl'], 'u1');
    });

    test('仅书名匹配', () {
      final score = scoreCuratedMatch(
        curatedName: '三体',
        curatedAuthor: '刘慈欣',
        resultName: '三体',
        resultAuthor: '',
      );
      expect(score.kind, CuratedMatchKind.exactName);

      final decision = decideCuratedOpen(
        curatedName: '三体',
        curatedAuthor: '刘慈欣',
        results: [
          {'name': '三体', 'author': '', 'bookUrl': 'u1'},
        ],
      );
      expect(decision.action, CuratedOpenAction.openDetail);
    });

    test('书名带噪声后缀：凡人修仙传_免费阅读', () {
      final score = scoreCuratedMatch(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        resultName: '凡人修仙传_免费阅读',
        resultAuthor: '忘语',
      );
      expect(score.kind, CuratedMatchKind.nameWithNoiseSuffix);

      final decision = decideCuratedOpen(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        results: [
          {
            'name': '凡人修仙传_免费阅读',
            'author': '忘语',
            'bookUrl': 'u1',
          },
        ],
      );
      expect(decision.action, CuratedOpenAction.openDetail);
    });

    test('完全不相关 → showSearchResults 或 notFound', () {
      final score = scoreCuratedMatch(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        resultName: '斗破苍穹',
        resultAuthor: '天蚕土豆',
      );
      expect(score.kind, CuratedMatchKind.none);

      final empty = decideCuratedOpen(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        results: const [],
      );
      expect(empty.action, CuratedOpenAction.notFound);

      final unrelated = decideCuratedOpen(
        curatedName: '凡人修仙传',
        curatedAuthor: '忘语',
        results: [
          {'name': '斗破苍穹', 'author': '天蚕土豆', 'bookUrl': 'u1'},
        ],
      );
      expect(unrelated.action, CuratedOpenAction.showSearchResults);
    });

    test('多个高分候选不确定时展示搜索结果', () {
      final decision = decideCuratedOpen(
        curatedName: '修真',
        curatedAuthor: '',
        results: [
          {'name': '修真聊天群', 'author': 'A', 'bookUrl': 'u1'},
          {'name': '修真世界', 'author': 'B', 'bookUrl': 'u2'},
        ],
      );
      expect(decision.action, CuratedOpenAction.showSearchResults);
      expect(decision.candidates.length, greaterThanOrEqualTo(2));
    });

    test('buildCuratedSearchKeyword', () {
      expect(buildCuratedSearchKeyword('三体', '刘慈欣'), '三体 刘慈欣');
      expect(buildCuratedSearchKeyword('三体', ''), '三体');
      expect(buildCuratedSearchKeyword('', '刘慈欣'), '刘慈欣');
    });
  });

  group('CuratedCoverResolver.pickCoverFromResults', () {
    test('挑最高匹配且带封面的结果', () {
      final cover = CuratedCoverResolver.pickCoverFromResults(
        curatedName: '三体',
        curatedAuthor: '刘慈欣',
        results: [
          {
            'name': '关于三体',
            'author': '刘慈欣',
            'coverUrl': 'https://a.example/weak.jpg',
          },
          {
            'name': '三体',
            'author': '刘慈欣',
            'coverUrl': 'https://a.example/best.jpg',
          },
          {
            'name': '三体',
            'author': '刘慈欣',
            'coverUrl': '',
          },
        ],
      );
      expect(cover, 'https://a.example/best.jpg');
    });

    test('无封面或无关结果 → null', () {
      expect(
        CuratedCoverResolver.pickCoverFromResults(
          curatedName: '三体',
          curatedAuthor: '刘慈欣',
          results: [
            {'name': '三体', 'author': '刘慈欣', 'coverUrl': ''},
            {'name': '球状闪电', 'author': '刘慈欣', 'coverUrl': 'https://x'},
          ],
        ),
        isNull,
      );
    });
  });
}
