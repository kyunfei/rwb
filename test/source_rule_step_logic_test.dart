import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/source_rule_step_logic.dart';

void main() {
  group('previewRuleOutput', () {
    test('截断过长文本', () {
      final long = 'a' * 600;
      final preview = previewRuleOutput(long, maxChars: 50);
      expect(preview.length, lessThan(80));
      expect(preview.contains('共600字'), isTrue);
    });

    test('列表预览', () {
      final preview = previewRuleOutput(['一', '二', '三', '四']);
      expect(preview.contains('列表(4)'), isTrue);
      expect(preview.contains('…'), isTrue);
    });

    test('null / 空', () {
      expect(previewRuleOutput(null), '<null>');
      expect(previewRuleOutput('   '), '<空>');
    });
  });

  group('field specs & logs', () {
    test('searchRuleFields 顺序含 bookList', () {
      final fields = searchRuleFields(bookList: 'class.book', name: 'tag.a@text');
      expect(fields.first.field, 'bookList');
      expect(fields.first.isList, isTrue);
      expect(fields[1].expression, 'tag.a@text');
    });

    test('formatRuleStepLogs 失败与跳过', () {
      final skipped = buildSkippedStep('搜索', 'intro');
      final skipLogs = formatRuleStepLogs(skipped);
      expect(skipLogs.last, contains('未配置'));

      final failed = buildStepResult(
        stage: '搜索',
        field: 'name',
        expression: 'tag.h1@text',
        success: false,
        error: '结果为空',
      );
      final failLogs = formatRuleStepLogs(failed);
      expect(failLogs.any((l) => l.contains('失败')), isTrue);
      expect(failLogs.any((l) => l.contains('tag.h1@text')), isTrue);
    });

    test('成功匹配带数量', () {
      final ok = buildStepResult(
        stage: '目录',
        field: 'chapterList',
        expression: 'tag.li',
        success: true,
        value: [1, 2, 3],
        matchCount: 3,
      );
      final logs = formatRuleStepLogs(ok);
      expect(logs.last, contains('匹配: 3'));
    });
  });
}
