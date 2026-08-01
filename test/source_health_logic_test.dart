import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/source_health.dart';
import 'package:mr/services/source_health_logic.dart';

void main() {
  group('judgeSourceHealth', () {
    test('四步全成功 → available', () {
      final result = judgeSourceHealth(
        sourceUrl: 'u',
        sourceName: 'n',
        steps: const [
          SourceHealthStep(name: kHealthStepSearch, success: true, durationMs: 10),
          SourceHealthStep(name: kHealthStepDetail, success: true, durationMs: 20),
          SourceHealthStep(name: kHealthStepToc, success: true, durationMs: 30),
          SourceHealthStep(name: kHealthStepContent, success: true, durationMs: 40),
        ],
      );
      expect(result.status, SourceHealthStatus.available);
      expect(result.totalMs, 100);
      expect(result.failReason, isNull);
    });

    test('搜索失败 → failed', () {
      final result = judgeSourceHealth(
        sourceUrl: 'u',
        sourceName: 'n',
        steps: const [
          SourceHealthStep(
            name: kHealthStepSearch,
            success: false,
            durationMs: 5,
            error: '超时',
          ),
        ],
      );
      expect(result.status, SourceHealthStatus.failed);
      expect(result.failReason, '超时');
    });

    test('搜索成功后续失败 → partial', () {
      final result = judgeSourceHealth(
        sourceUrl: 'u',
        sourceName: 'n',
        steps: const [
          SourceHealthStep(name: kHealthStepSearch, success: true, durationMs: 10),
          SourceHealthStep(
            name: kHealthStepDetail,
            success: false,
            durationMs: 8,
            error: '详情空',
          ),
        ],
      );
      expect(result.status, SourceHealthStatus.partial);
      expect(result.failReason, '详情空');
    });

    test('空步骤 → failed', () {
      final result = judgeSourceHealth(
        sourceUrl: 'u',
        sourceName: 'n',
        steps: const [],
      );
      expect(result.status, SourceHealthStatus.failed);
    });
  });

  group('filter/sort/collect', () {
    final sample = [
      const SourceHealthResult(
        sourceUrl: 'https://a.com',
        sourceName: 'Alpha',
        status: SourceHealthStatus.available,
        steps: [],
        totalMs: 100,
      ),
      const SourceHealthResult(
        sourceUrl: 'https://b.com',
        sourceName: 'Beta',
        status: SourceHealthStatus.failed,
        steps: [],
        totalMs: 50,
        failReason: '搜索无结果',
      ),
      const SourceHealthResult(
        sourceUrl: 'https://c.com',
        sourceName: 'Gamma',
        status: SourceHealthStatus.partial,
        steps: [],
        totalMs: 80,
        failReason: '目录空',
      ),
    ];

    test('按状态筛选', () {
      final failed = filterHealthResults(
        sample,
        status: SourceHealthStatus.failed,
      );
      expect(failed.length, 1);
      expect(failed.single.sourceName, 'Beta');
    });

    test('关键词筛选', () {
      final hit = filterHealthResults(sample, keyword: '目录');
      expect(hit.map((e) => e.sourceName), ['Gamma']);
    });

    test('按耗时排序', () {
      final sorted = sortHealthResults(
        sample,
        sort: SourceHealthSort.duration,
        ascending: true,
      );
      expect(sorted.map((e) => e.totalMs).toList(), [50, 80, 100]);
    });

    test('收集失效 url', () {
      expect(collectFailedSourceUrls(sample), ['https://b.com']);
    });
  });
}
