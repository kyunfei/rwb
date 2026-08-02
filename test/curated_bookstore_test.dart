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

  // 真机上这个解析器会给整个 Tab 的 50+ 本无封面书各发一次真实多源搜索，把
  // 点书路径饿死到 31 秒。下面这些用例锁住「不管资产缺多少封面都烧不动网络」。
  group('CuratedCoverResolver 限流', () {
    BookSource src(String url, {int weight = 0}) => BookSource(
          bookSourceUrl: url,
          bookSourceName: url,
          searchUrl: '$url/search?q={{key}}',
          weight: weight,
        );

    CuratedBook book(int i) =>
        CuratedBook(id: 'id-$i', name: '书$i', author: '作者$i');

    /// 反复让事件循环空转，把 resolver 里串行排队的异步 job 全部推完。
    Future<void> drain([int times = 200]) async {
      for (var i = 0; i < times; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    /// 永远拿不到封面的源：有响应但结果里没有封面。
    CuratedCoverResolver coverlessResolver({
      required List<String> calls,
      int maxConcurrentBooks = 1,
      int maxSourcesPerBook = 1,
      int maxQueueLength = 100,
      int maxBooksPerSession = 100,
      int failureCircuitThreshold = 100,
    }) {
      return CuratedCoverResolver(
        maxConcurrentBooks: maxConcurrentBooks,
        maxSourcesPerBook: maxSourcesPerBook,
        maxQueueLength: maxQueueLength,
        maxBooksPerSession: maxBooksPerSession,
        failureCircuitThreshold: failureCircuitThreshold,
        cacheStore: MemoryCoverCacheStore(),
        searcher: (source, keyword) async {
          calls.add(keyword);
          return const [];
        },
      );
    }

    test('默认参数把单本最坏成本从 48s 压到 8s', () {
      final resolver = CuratedCoverResolver(
        cacheStore: MemoryCoverCacheStore(),
      );
      expect(resolver.maxConcurrentBooks, 2);
      expect(resolver.maxSourcesPerBook, 2);
      expect(resolver.perSourceTimeout, const Duration(seconds: 4));
      expect(resolver.maxQueueLength, 24);
      expect(resolver.maxBooksPerSession, 60);
      expect(resolver.failureCircuitThreshold, 6);
      // 串行重试的最坏墙钟：原来 4×12s=48s
      expect(
        resolver.perSourceTimeout * resolver.maxSourcesPerBook,
        const Duration(seconds: 8),
      );
    });

    test('连续失败到阈值就熔断：清空队列且不再发起任何搜索', () async {
      final calls = <String>[];
      final resolver = coverlessResolver(
        calls: calls,
        failureCircuitThreshold: 3,
      );

      for (var i = 0; i < 12; i++) {
        resolver.enqueue(book: book(i), sources: [src('http://a')]);
      }
      await drain();

      expect(calls, hasLength(3), reason: '第 3 本失败即熔断，后面 9 本一次都不发');
      expect(resolver.isCircuitOpen, isTrue);
      expect(resolver.queueLength, 0, reason: '熔断时队列被清空');

      resolver.enqueue(book: book(99), sources: [src('http://a')]);
      await drain();
      expect(calls, hasLength(3), reason: '熔断后新入队被拒绝');
    });

    test('拿到封面会清零连续失败计数，不会被零星失败熔断', () async {
      final calls = <String>[];
      final resolver = CuratedCoverResolver(
        maxConcurrentBooks: 1,
        maxSourcesPerBook: 1,
        failureCircuitThreshold: 3,
        cacheStore: MemoryCoverCacheStore(),
        searcher: (source, keyword) async {
          calls.add(keyword);
          // 偶数本给封面，奇数本不给：失败永远连不满 3 个
          if (calls.length.isEven) return const [];
          return [
            {
              'name': keyword.split(' ').first,
              'author': keyword.split(' ').last,
              'coverUrl': 'https://cover.example/${calls.length}.jpg',
            },
          ];
        },
      );

      for (var i = 0; i < 8; i++) {
        resolver.enqueue(book: book(i), sources: [src('http://a')]);
      }
      await drain();

      expect(resolver.isCircuitOpen, isFalse);
      expect(calls, hasLength(8));
    });

    test('resetCircuit 重新开闸（导入新书源的场景）', () async {
      final calls = <String>[];
      final resolver = coverlessResolver(
        calls: calls,
        failureCircuitThreshold: 2,
      );

      for (var i = 0; i < 5; i++) {
        resolver.enqueue(book: book(i), sources: [src('http://a')]);
      }
      await drain();
      expect(resolver.isCircuitOpen, isTrue);
      expect(calls, hasLength(2));

      resolver.resetCircuit();
      expect(resolver.isCircuitOpen, isFalse);
      expect(resolver.startedJobCount, 0);

      // 之前失败过的书也能重试（新源可能有封面）
      resolver.enqueue(book: book(0), sources: [src('http://a')]);
      await drain();
      expect(calls, hasLength(3));
    });

    test('pause 期间不启动新 job，resume 后继续消费队列', () async {
      final calls = <String>[];
      final resolver = coverlessResolver(calls: calls, maxConcurrentBooks: 2);

      resolver.pause();
      expect(resolver.isPaused, isTrue);
      for (var i = 0; i < 4; i++) {
        resolver.enqueue(book: book(i), sources: [src('http://a')]);
      }
      await drain();

      expect(calls, isEmpty, reason: 'pause 期间一个搜索都不该发出');
      expect(resolver.startedJobCount, 0);
      expect(resolver.queueLength, 4, reason: '入队仍被接受，只是不启动');

      resolver.resume();
      await drain();
      expect(resolver.isPaused, isFalse);
      expect(calls, hasLength(4));
    });

    test('pause 用引用计数：重叠 pause 要配同样多次 resume', () async {
      final calls = <String>[];
      final resolver = coverlessResolver(calls: calls);

      resolver.pause();
      resolver.pause();
      resolver.enqueue(book: book(1), sources: [src('http://a')]);
      await drain();
      expect(calls, isEmpty);

      resolver.resume();
      await drain();
      expect(calls, isEmpty, reason: '还剩一层 pause 没释放');

      resolver.resume();
      await drain();
      expect(calls, hasLength(1));
    });

    test('pause 会抢占在飞 job：不再试下一个源，且不算失败', () async {
      final calls = <String>[];
      final gates = <Completer<List<Map<String, dynamic>>>>[];
      final resolver = CuratedCoverResolver(
        maxConcurrentBooks: 1,
        maxSourcesPerBook: 3,
        cacheStore: MemoryCoverCacheStore(),
        searcher: (source, keyword) {
          calls.add(source.bookSourceUrl);
          final gate = Completer<List<Map<String, dynamic>>>();
          gates.add(gate);
          return gate.future;
        },
      );

      resolver.enqueue(
        book: book(1),
        sources: [
          src('http://a', weight: 3),
          src('http://b', weight: 2),
          src('http://c', weight: 1),
        ],
      );
      expect(calls, ['http://a']);

      resolver.pause();
      gates.first.complete(const []); // 首源无封面返回
      await drain();

      expect(calls, ['http://a'], reason: 'pause 后不该再开 b / c');
      expect(
        resolver.consecutiveFailureCount,
        0,
        reason: '被抢占而中途放弃不算失败，不该把熔断计数往上推',
      );
    });

    test('队列长度到上限后直接丢弃，不再无限堆积', () async {
      final calls = <String>[];
      final hang = Completer<List<Map<String, dynamic>>>();
      final resolver = CuratedCoverResolver(
        maxConcurrentBooks: 2,
        maxSourcesPerBook: 1,
        maxQueueLength: 3,
        cacheStore: MemoryCoverCacheStore(),
        searcher: (source, keyword) {
          calls.add(keyword);
          return hang.future; // 挂住并发位，让队列堆起来
        },
      );

      // 模拟反复切 Tab：一次性丢 50 本进来
      for (var i = 0; i < 50; i++) {
        resolver.enqueue(book: book(i), sources: [src('http://a')]);
      }
      await drain(5);

      expect(resolver.activeJobCount, 2);
      expect(resolver.queueLength, 3, reason: '超出上限的书被丢弃而不是排队');
      expect(calls, hasLength(2));

      hang.complete(const []);
      await drain();
    });

    test('同一本书每帧重复入队只排一份', () async {
      final calls = <String>[];
      final hang = Completer<List<Map<String, dynamic>>>();
      final resolver = CuratedCoverResolver(
        maxConcurrentBooks: 1,
        maxSourcesPerBook: 1,
        cacheStore: MemoryCoverCacheStore(),
        searcher: (source, keyword) {
          calls.add(keyword);
          return hang.future;
        },
      );

      // 第一本占住唯一的并发位
      resolver.enqueue(book: book(0), sources: [src('http://a')]);
      // 第二本反复入队（页面每次 rebuild 都会 requestCovers）
      for (var i = 0; i < 10; i++) {
        resolver.enqueue(book: book(1), sources: [src('http://a')]);
      }

      expect(resolver.queueLength, 1, reason: '10 次重复入队只应留下 1 个 job');
      expect(calls, hasLength(1));

      hang.complete(const []);
      await drain();
    });

    test('会话总量到上限后不再发起搜索', () async {
      final calls = <String>[];
      final resolver = coverlessResolver(calls: calls, maxBooksPerSession: 4);

      for (var i = 0; i < 30; i++) {
        resolver.enqueue(book: book(i), sources: [src('http://a')]);
      }
      await drain();

      expect(calls, hasLength(4));
      expect(resolver.startedJobCount, 4);
      expect(resolver.queueLength, 0, reason: '配额用尽后剩下的队列被释放');

      resolver.enqueue(book: book(99), sources: [src('http://a')]);
      await drain();
      expect(calls, hasLength(4), reason: '会话配额用尽后新入队被拒绝');
    });

    test('书源还没就绪时不消耗配额、也不把书永久拉黑', () async {
      final calls = <String>[];
      final resolver = coverlessResolver(calls: calls, maxBooksPerSession: 2);

      // DiscoveryProvider.loadBookSources() 是异步的，头几帧 sources 可能是空的
      for (var i = 0; i < 10; i++) {
        resolver.enqueue(book: book(i), sources: const []);
      }
      await drain();
      expect(calls, isEmpty);
      expect(resolver.startedJobCount, 0, reason: '空源列表不该烧掉会话配额');

      // 源就绪后同一批书还能再来
      resolver.enqueue(book: book(0), sources: [src('http://a')]);
      await drain();
      expect(calls, hasLength(1));
    });

    test('已有封面 / 已缓存的书不会发起搜索', () async {
      final calls = <String>[];
      final cache = MemoryCoverCacheStore();
      final resolver = CuratedCoverResolver(
        cacheStore: cache,
        searcher: (source, keyword) async {
          calls.add(keyword);
          return const [];
        },
      );

      // 资产自带封面
      resolver.enqueue(
        book: const CuratedBook(
          id: 'a',
          name: '有封面',
          author: '作者',
          coverUrl: 'https://cover.example/a.jpg',
        ),
        sources: [src('http://a')],
      );
      // 持久化缓存里已有
      final cached = book(7);
      cache.data[CuratedCoverResolver.cacheKey(cached.name, cached.author)] =
          'https://cover.example/cached.jpg';
      String? notified;
      resolver.enqueue(
        book: cached,
        sources: [src('http://a')],
        onResolved: (url) => notified = url,
      );
      await drain();

      expect(calls, isEmpty);
      expect(notified, 'https://cover.example/cached.jpg');
    });
  });
}
