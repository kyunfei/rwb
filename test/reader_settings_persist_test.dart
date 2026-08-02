import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mr/providers/reader_provider.dart';
import 'package:mr/services/storage_service.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('rwb_reader_settings_test');
    Hive.init(dir.path);
    await StorageService.instance.init();
  });

  test('手选背景色后关闭跟随系统夜间，再进阅读器不会被系统主题盖掉', () {
    final provider = ReaderProvider();
    expect(provider.nightModeFollowSystem, isTrue);

    const custom = Color(0xFFE8F5E9);
    provider.setBackgroundColor(custom);

    expect(provider.nightModeFollowSystem, isFalse);
    expect(provider.backgroundColor.toARGB32(), custom.toARGB32());

    // 模拟再次进入阅读器时调用的系统夜间同步：不应再改用户背景
    provider.applyPlatformNightMode(Brightness.dark);
    expect(provider.backgroundColor.toARGB32(), custom.toARGB32());
  });

  test('字号/行距/翻页方式写入内存后可被再次读取（同进程全局生效）', () {
    final provider = ReaderProvider();
    provider.setFontSize(28);
    provider.setLineHeight(2.0);
    provider.setPageMode(PageMode.scroll);
    provider.setFontFamily('serif');

    expect(provider.fontSize, 28);
    expect(provider.lineHeight, 2.0);
    expect(provider.pageMode, PageMode.scroll);
    expect(provider.fontFamily, 'serif');
  });
}
