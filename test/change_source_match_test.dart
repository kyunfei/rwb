import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/change_source_match.dart';

void main() {
  group('ChangeSourceMatch.isSameBook', () {
    test('归一化后书名全等才算同一本', () {
      expect(
        ChangeSourceMatch.isSameBook(
          targetName: '《夜无疆》',
          targetAuthor: '辰东',
          candidateName: '夜无疆',
          candidateAuthor: '辰东',
        ),
        isTrue,
      );
      expect(
        ChangeSourceMatch.isSameBook(
          targetName: '夜无疆',
          targetAuthor: '辰东',
          candidateName: '夜无疆外传',
          candidateAuthor: '辰东',
        ),
        isFalse,
      );
    });

    test('书名只是包含关系不算匹配（旧逻辑会误放行）', () {
      expect(
        ChangeSourceMatch.isSameBook(
          targetName: '永夜',
          targetAuthor: '甲',
          candidateName: '永夜君王',
          candidateAuthor: '甲',
        ),
        isFalse,
      );
    });

    test('目标有作者时，结果作者不同则否决', () {
      expect(
        ChangeSourceMatch.isSameBook(
          targetName: '夜无疆',
          targetAuthor: '辰东',
          candidateName: '夜无疆',
          candidateAuthor: '别人',
        ),
        isFalse,
      );
    });

    test('目标有作者、结果作者为空时仍接受（站点常漏作者）', () {
      expect(
        ChangeSourceMatch.isSameBook(
          targetName: '夜无疆',
          targetAuthor: '辰东',
          candidateName: '夜无疆',
          candidateAuthor: '',
        ),
        isTrue,
      );
    });

    test('目标无作者时只按书名', () {
      expect(
        ChangeSourceMatch.isSameBook(
          targetName: '夜无疆',
          targetAuthor: '',
          candidateName: '夜无疆',
          candidateAuthor: '任意作者',
        ),
        isTrue,
      );
    });
  });

  group('ChangeSourceMatch.selectSourceEntries', () {
    test('剔除同名异书与书名相似的杂书', () {
      final selected = ChangeSourceMatch.selectSourceEntries(
        targetName: '夜无疆',
        targetAuthor: '辰东',
        hits: [
          {
            'sourceUrl': 'http://a.com',
            'sourceName': '源A',
            'name': '夜无疆',
            'author': '辰东',
            'lastChapter': '第1章',
          },
          {
            'sourceUrl': 'http://b.com',
            'sourceName': '源B',
            'name': '夜无疆',
            'author': '别人',
            'lastChapter': '第9章',
          },
          {
            'sourceUrl': 'http://c.com',
            'sourceName': '源C',
            'name': '永夜君王',
            'author': '辰东',
            'lastChapter': '第2章',
          },
        ],
      );

      expect(selected.map((e) => e['sourceUrl']), ['http://a.com']);
    });

    test('同一书源多条命中只留一条，优先作者精确且最新章节非空', () {
      final selected = ChangeSourceMatch.selectSourceEntries(
        targetName: '夜无疆',
        targetAuthor: '辰东',
        hits: [
          {
            'sourceUrl': 'http://a.com',
            'sourceName': '源A',
            'name': '夜无疆',
            'author': '',
            'lastChapter': '旧章',
          },
          {
            'sourceUrl': 'http://a.com',
            'sourceName': '源A',
            'name': '夜无疆',
            'author': '辰东',
            'lastChapter': '',
          },
          {
            'sourceUrl': 'http://a.com',
            'sourceName': '源A',
            'name': '夜无疆',
            'author': '辰东',
            'lastChapter': '第776章',
          },
        ],
      );

      expect(selected, hasLength(1));
      expect(selected.single['lastChapter'], '第776章');
      expect(selected.single['author'], '辰东');
    });

    test('当前书源排第一', () {
      final selected = ChangeSourceMatch.selectSourceEntries(
        targetName: '夜无疆',
        targetAuthor: '辰东',
        currentSourceUrl: 'http://z.com',
        hits: [
          {
            'sourceUrl': 'http://a.com',
            'sourceName': '爱奇',
            'name': '夜无疆',
            'author': '辰东',
          },
          {
            'sourceUrl': 'http://z.com',
            'sourceName': '当前源',
            'name': '夜无疆',
            'author': '辰东',
          },
        ],
      );

      expect(selected.first['sourceUrl'], 'http://z.com');
      expect(selected, hasLength(2));
    });

    test('搜索关键词只用书名', () {
      expect(ChangeSourceMatch.searchKeyword(' 夜无疆 '), '夜无疆');
    });
  });
}
