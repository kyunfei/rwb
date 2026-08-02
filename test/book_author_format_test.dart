import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/source_engine/web_book.dart';

void main() {
  // 真机上详情页显示成「作者： 作  者：会说话的肘子」：站点把标签排版成
  // 「作　者：」塞在字段里，而洗前缀用的是字面量比对，一个都对不上。
  group('作者字段洗标签', () {
    String fmt(String s) => WebBook.formatBookAuthorForTest(s);

    test('真机原样：标签内部有空格也要洗掉', () {
      expect(fmt('作  者：会说话的肘子'), '会说话的肘子');
    });

    test('全角空格与全角冒号', () {
      expect(fmt('作　者：会说话的肘子'), '会说话的肘子');
      expect(fmt('作者：辰东'), '辰东');
    });

    test('半角冒号与前后空白', () {
      expect(fmt('  作者: 辰东  '), '辰东');
    });

    test('著者/译者/文 也算标签', () {
      expect(fmt('著者：辰东'), '辰东');
      expect(fmt('译者：辰东'), '辰东');
      expect(fmt('文：辰东'), '辰东');
    });

    test('尾巴上的「著」照旧去掉', () {
      expect(fmt('会说话的肘子 著'), '会说话的肘子');
    });

    test('不误删：没有冒号就不当标签，否则「文心」会被削成「心」', () {
      expect(fmt('文心'), '文心');
      expect(fmt('作者不详'), '作者不详');
    });

    test('不误删：正常作者名原样返回', () {
      expect(fmt('辰东'), '辰东');
      expect(fmt('I. Asimov'), 'I. Asimov');
    });

    test('空值安全', () {
      expect(fmt(''), '');
      expect(fmt('   '), '');
      expect(fmt('作者：'), '');
    });
  });
}
