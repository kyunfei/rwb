import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/models/curated_bookstore.dart';
import 'package:mr/services/bookstore/curated_book_opener.dart';
import 'package:mr/services/bookstore/curated_cover_resolver.dart';
import 'package:mr/services/bookstore/curated_match.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('canStopCuratedOpenSearch', () {
    test('空结果 / 仅弱相关 → 不能停', () {
      expect(
        canStopCuratedOpenSearch(
          curatedName: '三体',
          curatedAuthor: '刘慈欣',
          results: const [],
        ),
        isFalse,
      );
      expect(
        canStopCuratedOpenSearch(
          curatedName: '三体',
          curatedAuthor: '刘慈欣',
          results: [
            {'name': '关于三体的书评', 'author': '他人', 'bookUrl': 'u1'},
          ],
        ),
        isFalse,
      );
    });

    test('已能直达详情 → 可以停', () {
      expect(
        canStopCuratedOpenSearch(
          curatedName: '三体',
          curatedAuthor: '刘慈欣',
          results: [
            {'name': '三体', 'author': '刘慈欣', 'bookUrl': 'u1'},
          ],
        ),
        isTrue,
      );
      expect(
        canStopCuratedOpenSearch(
          curatedName: '凡人修仙传',
          curatedAuthor: '忘语',
          results: [
            {
              'name': '凡人修仙传_免费阅读',
              'author': '忘语',
              'bookUrl': 'u1',
            },
          ],
        ),
        isTrue,
      );
    });

    test('多个不确定候选 → 继续等（可能还有更好命中）', () {
      expect(
        canStopCuratedOpenSearch(
          curatedName: '修真',
          curatedAuthor: '',
          results: [
            {'name': '修真聊天群', 'author': 'A', 'bookUrl': 'u1'},
            {'name': '修真世界', 'author': 'B', 'bookUrl': 'u2'},
          ],
        ),
        isFalse,
      );
    });
  });

  group('CuratedBookOpener', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    BookSource src(String url, {int weight = 0}) => BookSource(
          bookSourceUrl: url,
          bookSourceName: url,
          searchUrl: '$url/search?q={{key}}',
          weight: weight,
        );

    test('高置信命中后提前结束，不等慢源跑完', () async {
      final called = <String>[];
      // 用 Completer 挂起慢源，避免 Future.delayed 在测试结束时留下 pending timer
      final slowHang = Completer<List<Map<String, dynamic>>>();
      final opener = CuratedBookOpener(
        maxConcurrentSearches: 2,
        sourceLimit: 4,
        timeBudget: const Duration(seconds: 5),
        searcher: (source, keyword) async {
          called.add(source.bookSourceUrl);
          if (source.bookSourceUrl == 'http://fast') {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            return [
              {
                'name': '三体',
                'author': '刘慈欣',
                'bookUrl': 'http://fast/book',
              },
            ];
          }
          return slowHang.future;
        },
      );

      final sw = Stopwatch()..start();
      final result = await opener.open(
        const CuratedBook(id: '1', name: '三体', author: '刘慈欣'),
        sources: [
          src('http://slow-a', weight: 1),
          src('http://fast', weight: 100),
          src('http://slow-b', weight: 1),
          src('http://slow-c', weight: 1),
        ],
      );
      sw.stop();

      expect(result.decision.action, CuratedOpenAction.openDetail);
      expect(result.decision.bestResult?['bookUrl'], 'http://fast/book');
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      // 质量排序应先排到 fast；慢源即使被启动，也不应拖住 open()
      expect(called, contains('http://fast'));
      if (!slowHang.isCompleted) {
        slowHang.complete(const []);
      }
    });

    test('只向质量排序后的头部源发搜索', () async {
      final called = <String>[];
      final opener = CuratedBookOpener(
        maxConcurrentSearches: 8,
        sourceLimit: 2,
        timeBudget: const Duration(seconds: 3),
        searcher: (source, keyword) async {
          called.add(source.bookSourceUrl);
          return const [];
        },
      );

      await opener.open(
        const CuratedBook(id: '1', name: '三体', author: '刘慈欣'),
        sources: [
          src('http://worst', weight: 0),
          src('http://mid', weight: 50),
          src('http://best', weight: 200),
        ],
      );

      expect(called.toSet(), {'http://best', 'http://mid'});
      expect(called, isNot(contains('http://worst')));
    });

    test('墙钟预算到点后用已有结果决策，不再干等', () async {
      final hang = Completer<List<Map<String, dynamic>>>();
      final opener = CuratedBookOpener(
        maxConcurrentSearches: 2,
        sourceLimit: 4,
        timeBudget: const Duration(milliseconds: 120),
        searcher: (source, keyword) => hang.future,
      );

      final sw = Stopwatch()..start();
      final result = await opener.open(
        const CuratedBook(id: '1', name: '三体', author: '刘慈欣'),
        sources: [
          src('http://a', weight: 3),
          src('http://b', weight: 2),
        ],
      );
      sw.stop();

      expect(result.decision.action, CuratedOpenAction.notFound);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      if (!hang.isCompleted) {
        hang.complete(const []);
      }
    });

    test('提前收敛不触发监听重入：stopSearch 的通知不得再回到判定里', () async {
      // stopSearch() 末尾会 notifyListeners()，而 notifyListeners 是同步派发的。
      // 若收敛判定在 stopSearch 之后才落定，通知会立刻重入判定并再次 stopSearch，
      // 一路递归到爆栈；StackOverflowError 又被 ChangeNotifier 的 try/catch 吞掉
      // 转成 FlutterError，所以只看返回值和耗时的用例发现不了——真机上这段递归
      // 白烧了 21 秒，点书要等 29 秒。这里直接盯 FlutterError 有没有被报出来。
      final errors = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      final hang = Completer<List<Map<String, dynamic>>>();
      final opener = CuratedBookOpener(
        maxConcurrentSearches: 2,
        sourceLimit: 6,
        timeBudget: const Duration(seconds: 5),
        searcher: (source, keyword) async {
          if (source.bookSourceUrl == 'http://hit') {
            return [
              {'name': '三体', 'author': '刘慈欣', 'bookUrl': 'http://hit/b'},
            ];
          }
          return hang.future;
        },
      );

      final result = await opener.open(
        const CuratedBook(id: '1', name: '三体', author: '刘慈欣'),
        sources: [
          src('http://hit', weight: 100),
          src('http://slow1', weight: 90),
          src('http://slow2', weight: 80),
        ],
      );

      expect(result.decision.action, CuratedOpenAction.openDetail);
      expect(errors, isEmpty, reason: '收敛路径报了 Flutter 错误（很可能是递归爆栈）');
      if (!hang.isCompleted) {
        hang.complete(const []);
      }
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
