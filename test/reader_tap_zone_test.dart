import 'package:flutter_test/flutter_test.dart';
import 'package:mr/providers/reader_provider.dart';

void main() {
  // 真机上「点右侧边缘不翻页，只有滑动才行」的根因：九宫格默认除中列外
  // 全是 none，点左右两侧本来就什么都不做。
  group('阅读器点击区默认值', () {
    test('左列上一页 / 中列菜单 / 右列下一页', () {
      final m = defaultTapZoneActions();
      expect(m, hasLength(3));
      for (final row in m) {
        expect(row, hasLength(3));
        expect(row[0], TapZoneAction.previousPage);
        expect(row[1], TapZoneAction.showMenu);
        expect(row[2], TapZoneAction.nextPage);
      }
    });

    test('九格里不许有 none：那等于一片点了没反应的死区', () {
      for (final row in defaultTapZoneActions()) {
        expect(row.contains(TapZoneAction.none), isFalse);
      }
    });
  });

  group('还原存档里的点击区配置', () {
    test('没存过 → 默认', () {
      expect(normalizeTapZoneActions(null), defaultTapZoneActions());
    });

    test('整块无动作 → 当成没配过，退回默认', () {
      final allNone = [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ];
      expect(normalizeTapZoneActions(allNone), defaultTapZoneActions());
    });

    test('旧默认(只有中列菜单) → 也退回默认，否则老用户永远修不好', () {
      // 旧默认: 中间与下方中列 showMenu, 其余 none。真机上存档里就是这一份，
      // 只判「整块无动作」会放过它，边缘照旧点不动。
      final legacy = [
        [0, 0, 0],
        [0, 1, 0],
        [0, 1, 0],
      ];
      expect(normalizeTapZoneActions(legacy), defaultTapZoneActions());
    });

    test('只差一格就不算旧默认，用户的配置要留住', () {
      final almostLegacy = [
        [0, 0, 0],
        [0, 1, 3], // 右中格用户改成了下一页
        [0, 1, 0],
      ];
      final out = normalizeTapZoneActions(almostLegacy);
      expect(out[1][2], TapZoneAction.nextPage);
      expect(out[0][0], TapZoneAction.none);
    });

    test('用户真配过的矩阵原样保留', () {
      final custom = [
        [3, 3, 3],
        [2, 1, 3],
        [4, 1, 5],
      ];
      final out = normalizeTapZoneActions(custom);
      expect(out[0][0], TapZoneAction.nextPage);
      expect(out[1][0], TapZoneAction.previousPage);
      expect(out[2][0], TapZoneAction.previousChapter);
      expect(out[2][2], TapZoneAction.nextChapter);
    });

    test('形状不对 → 默认', () {
      expect(
        normalizeTapZoneActions([
          [1, 1],
          [1, 1],
        ]),
        defaultTapZoneActions(),
      );
      expect(
        normalizeTapZoneActions([
          [1, 1, 1],
          'bad',
          [1, 1, 1],
        ]),
        defaultTapZoneActions(),
      );
    });

    test('越界/非法枚举下标当 none，不抛异常', () {
      final out = normalizeTapZoneActions([
        [99, 1, -1],
        ['x', 1, null],
        [3, 1, 2],
      ]);
      expect(out[0][0], TapZoneAction.none);
      expect(out[0][2], TapZoneAction.none);
      expect(out[1][0], TapZoneAction.none);
      expect(out[2][0], TapZoneAction.nextPage);
    });
  });
}
