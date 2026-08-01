import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/book_source.dart';
import 'package:mr/models/source_subscription.dart';
import 'package:mr/services/source_import_logic.dart';

void main() {
  group('dedupeSourcesByUrl', () {
    test('后出现的同 url 覆盖先前', () {
      const a = BookSource(
        bookSourceUrl: 'https://a.com',
        bookSourceName: '旧',
      );
      const b = BookSource(
        bookSourceUrl: 'https://a.com',
        bookSourceName: '新',
      );
      const c = BookSource(
        bookSourceUrl: 'https://b.com',
        bookSourceName: 'B',
      );
      final result = dedupeSourcesByUrl([a, c, b]);
      expect(result.length, 2);
      expect(
        result.firstWhere((e) => e.bookSourceUrl == 'https://a.com').bookSourceName,
        '新',
      );
    });

    test('空 url 被丢弃', () {
      final result = dedupeSourcesByUrl([
        const BookSource(bookSourceUrl: '', bookSourceName: 'x'),
        const BookSource(bookSourceUrl: 'https://ok.com', bookSourceName: 'ok'),
      ]);
      expect(result.length, 1);
      expect(result.single.bookSourceUrl, 'https://ok.com');
    });
  });

  group('computeImportMergeStats', () {
    test('统计新增/更新/未变', () {
      const a = BookSource(
        bookSourceUrl: 'https://a.com',
        bookSourceName: 'A',
      );
      const bOld = BookSource(
        bookSourceUrl: 'https://b.com',
        bookSourceName: 'B-old',
      );
      const bNew = BookSource(
        bookSourceUrl: 'https://b.com',
        bookSourceName: 'B-new',
      );
      const c = BookSource(
        bookSourceUrl: 'https://c.com',
        bookSourceName: 'C',
      );
      final existing = {
        a.bookSourceUrl: a.toJson(),
        bOld.bookSourceUrl: bOld.toJson(),
      };
      final stats = computeImportMergeStats(
        incoming: [a, bNew, c],
        existingByUrl: existing,
      );
      expect(stats.unchanged, 1);
      expect(stats.updated, 1);
      expect(stats.added, 1);
    });
  });

  group('subscription upsert/remove', () {
    test('同 url 去重更新并保留旧 name', () {
      final current = [
        const SourceSubscription(url: 'https://s1.com', name: '订阅1'),
        const SourceSubscription(url: 'https://s2.com'),
      ];
      final next = upsertSubscription(
        current,
        const SourceSubscription(
          url: 'https://s1.com',
          lastAdded: 3,
          lastUpdated: 1,
        ),
      );
      expect(next.length, 2);
      final s1 = next.firstWhere((e) => e.url == 'https://s1.com');
      expect(s1.name, '订阅1');
      expect(s1.lastAdded, 3);
    });

    test('removeSubscription', () {
      final next = removeSubscription(
        const [
          SourceSubscription(url: 'https://a.com'),
          SourceSubscription(url: 'https://b.com'),
        ],
        'https://a.com',
      );
      expect(next.map((e) => e.url), ['https://b.com']);
    });
  });

  group('looksLikeSubscribeUrl', () {
    test('识别 http(s)', () {
      expect(looksLikeSubscribeUrl('https://x.com/a.json'), isTrue);
      expect(looksLikeSubscribeUrl('http://x.com'), isTrue);
      expect(looksLikeSubscribeUrl('{ "a": 1 }'), isFalse);
      expect(looksLikeSubscribeUrl('ftp://x.com'), isFalse);
    });
  });
}
