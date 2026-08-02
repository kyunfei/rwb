import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/curated_bookstore.dart';

/// 校验随包发布的策展清单本身。
///
/// `curated_bookstore_test.dart` 用内联 JSON 验解析器的容错，那套用例再全，也不会
/// 发现真实 asset 写错字段名——解析器是容错的，字段名错一个字母只会安静地少一块，
/// 书城四个 Tab 空着，直到真机上才发现。所以这里必须读真文件。
void main() {
  const assetPath = 'assets/bookstore/curated.json';

  late CuratedBookstore data;

  setUpAll(() {
    final file = File(assetPath);
    expect(file.existsSync(), isTrue, reason: '$assetPath 不存在');
    data = parseCuratedBookstore(jsonDecode(file.readAsStringSync()));
  });

  test('asset 已在 pubspec 里声明，否则运行时读不到', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('assets/bookstore/'),
      isTrue,
      reason: 'pubspec.yaml 未声明 assets/bookstore/',
    );
  });

  test('四个 Tab 的数据都不为空', () {
    expect(data.isEmpty, isFalse);
    expect(data.banners, isNotEmpty, reason: '精选页轮播为空');
    expect(data.shortcuts, isNotEmpty, reason: '快捷入口为空');
    expect(data.featuredSections, isNotEmpty, reason: '精选页区块为空');
    expect(data.categories, isNotEmpty, reason: '分类 Tab 为空');
    expect(data.rankings, isNotEmpty, reason: '榜单 Tab 为空');
    expect(data.lists, isNotEmpty, reason: '书单 Tab 为空');
    expect(data.booksById.length, greaterThan(100));
  });

  test('每个区块都有书，标题不为空', () {
    void checkSections(String label, List<List<String>> idLists,
        List<String> titles) {
      for (var i = 0; i < idLists.length; i++) {
        expect(titles[i].trim(), isNotEmpty, reason: '$label 第 $i 个标题为空');
        expect(idLists[i], isNotEmpty, reason: '$label「${titles[i]}」没有书');
      }
    }

    checkSections(
      '精选区块',
      data.featuredSections.map((s) => s.bookIds).toList(),
      data.featuredSections.map((s) => s.title).toList(),
    );
    checkSections(
      '分类',
      data.categories.map((s) => s.bookIds).toList(),
      data.categories.map((s) => s.title).toList(),
    );
    checkSections(
      '榜单',
      data.rankings.map((s) => s.bookIds).toList(),
      data.rankings.map((s) => s.title).toList(),
    );
    checkSections(
      '书单',
      data.lists.map((s) => s.bookIds).toList(),
      data.lists.map((s) => s.title).toList(),
    );
  });

  test('所有 bookId 引用都能解析，没有悬空引用', () {
    final dangling = <String>[];
    void check(String where, Iterable<String> ids) {
      for (final id in ids) {
        if (data.bookById(id) == null) dangling.add('$where -> $id');
      }
    }

    for (final b in data.banners) {
      check('banner ${b.id}', [b.bookId]);
    }
    for (final s in data.featuredSections) {
      check('精选区块 ${s.title}', s.bookIds);
    }
    for (final s in data.categories) {
      check('分类 ${s.title}', s.bookIds);
    }
    for (final s in data.rankings) {
      check('榜单 ${s.title}', s.bookIds);
    }
    for (final s in data.lists) {
      check('书单 ${s.title}', s.bookIds);
    }
    expect(dangling, isEmpty);
  });

  test('快捷入口都指向存在的书单', () {
    for (final s in data.shortcuts) {
      expect(
        data.listById(s.listId),
        isNotNull,
        reason: '快捷入口「${s.title}」指向的书单 ${s.listId} 不存在',
      );
    }
  });

  test('轮播都有文案与封面，否则首屏是空白图配空标题', () {
    for (final b in data.banners) {
      expect(b.tagline.trim(), isNotEmpty, reason: 'banner ${b.id} 没有文案');
      final book = data.bookById(b.bookId);
      expect(book, isNotNull);
      expect(book!.hasCover, isTrue,
          reason: '轮播书「${book.name}」没有封面');
    }
  });

  test('书名干净：无完结标记、无 HTML、长度合理', () {
    // 书名是拿去多源搜索的关键词。站点会把「(完)」贴在书名后，带着它搜必然搜不到。
    final finishedMark = RegExp(r'[（(\[【]\s*(完|完结|完本)\s*[）)\]】]');
    for (final book in data.booksById.values) {
      final name = book.name;
      expect(name.trim(), isNotEmpty);
      expect(name.length, lessThanOrEqualTo(40), reason: '书名过长: $name');
      expect(finishedMark.hasMatch(name), isFalse, reason: '书名含完结标记: $name');
      expect(name.contains('<'), isFalse, reason: '书名含 HTML: $name');
      expect(name.contains('第') && name.contains('章'), isFalse,
          reason: '书名疑似抓成了章节名: $name');
    }
  });

  test('作者不等于书名，否则搜索关键词会变成「书名 书名」', () {
    for (final book in data.booksById.values) {
      if (book.author.isEmpty) continue;
      expect(book.author, isNot(equals(book.name)), reason: book.name);
      expect(book.author.length, lessThanOrEqualTo(20),
          reason: '作者名过长: ${book.author}');
    }
  });
}
