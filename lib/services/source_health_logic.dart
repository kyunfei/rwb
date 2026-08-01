import '../models/source_health.dart';

/// 标准健康检查步骤名（固定顺序）
const kHealthStepSearch = '搜索';
const kHealthStepDetail = '详情';
const kHealthStepToc = '目录';
const kHealthStepContent = '正文';

const kHealthStepOrder = [
  kHealthStepSearch,
  kHealthStepDetail,
  kHealthStepToc,
  kHealthStepContent,
];

/// 根据各步成败判定三态与失败原因（纯逻辑）
SourceHealthResult judgeSourceHealth({
  required String sourceUrl,
  required String sourceName,
  required List<SourceHealthStep> steps,
}) {
  final totalMs =
      steps.fold<int>(0, (sum, step) => sum + step.durationMs);

  if (steps.isEmpty) {
    return SourceHealthResult(
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      status: SourceHealthStatus.failed,
      steps: steps,
      totalMs: totalMs,
      failReason: '未执行任何检测步骤',
    );
  }

  final byName = {for (final s in steps) s.name: s};
  final search = byName[kHealthStepSearch];
  final detail = byName[kHealthStepDetail];
  final toc = byName[kHealthStepToc];
  final content = byName[kHealthStepContent];

  if (search == null || !search.success) {
    return SourceHealthResult(
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      status: SourceHealthStatus.failed,
      steps: steps,
      totalMs: totalMs,
      failReason: search?.error ?? '搜索失败',
    );
  }

  final allOk = (detail?.success ?? false) &&
      (toc?.success ?? false) &&
      (content?.success ?? false);

  if (allOk) {
    return SourceHealthResult(
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      status: SourceHealthStatus.available,
      steps: steps,
      totalMs: totalMs,
    );
  }

  String? failReason;
  for (final step in [detail, toc, content]) {
    if (step != null && !step.success) {
      failReason = step.error ?? '${step.name}失败';
      break;
    }
  }

  return SourceHealthResult(
    sourceUrl: sourceUrl,
    sourceName: sourceName,
    status: SourceHealthStatus.partial,
    steps: steps,
    totalMs: totalMs,
    failReason: failReason ?? '后续步骤未完成',
  );
}

/// 筛选/排序辅助
List<SourceHealthResult> filterHealthResults(
  List<SourceHealthResult> results, {
  SourceHealthStatus? status,
  String keyword = '',
}) {
  final kw = keyword.trim().toLowerCase();
  return results.where((r) {
    if (status != null && r.status != status) return false;
    if (kw.isEmpty) return true;
    return r.sourceName.toLowerCase().contains(kw) ||
        r.sourceUrl.toLowerCase().contains(kw) ||
        (r.failReason?.toLowerCase().contains(kw) ?? false);
  }).toList();
}

enum SourceHealthSort {
  name,
  status,
  duration,
}

List<SourceHealthResult> sortHealthResults(
  List<SourceHealthResult> results, {
  SourceHealthSort sort = SourceHealthSort.status,
  bool ascending = true,
}) {
  final list = List<SourceHealthResult>.from(results);
  int cmp(SourceHealthResult a, SourceHealthResult b) {
    switch (sort) {
      case SourceHealthSort.name:
        return a.sourceName.compareTo(b.sourceName);
      case SourceHealthSort.duration:
        return a.totalMs.compareTo(b.totalMs);
      case SourceHealthSort.status:
        return a.status.index.compareTo(b.status.index);
    }
  }

  list.sort((a, b) => ascending ? cmp(a, b) : cmp(b, a));
  return list;
}

/// 收集应禁用的失效源 URL
List<String> collectFailedSourceUrls(List<SourceHealthResult> results) {
  return results
      .where((r) => r.status == SourceHealthStatus.failed)
      .map((r) => r.sourceUrl)
      .toList();
}
