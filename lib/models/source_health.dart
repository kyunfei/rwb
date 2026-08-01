/// 书源健康三态
enum SourceHealthStatus {
  /// 搜索→详情→目录→正文全部成功
  available,

  /// 至少搜索成功，但后续某步失败
  partial,

  /// 搜索失败或无法发起检测
  failed,
}

extension SourceHealthStatusX on SourceHealthStatus {
  String get label => switch (this) {
        SourceHealthStatus.available => '可用',
        SourceHealthStatus.partial => '部分可用',
        SourceHealthStatus.failed => '失效',
      };
}

/// 健康检查单步结果
class SourceHealthStep {
  final String name;
  final bool success;
  final int durationMs;
  final String? error;
  final String? detail;

  const SourceHealthStep({
    required this.name,
    required this.success,
    required this.durationMs,
    this.error,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'success': success,
        'durationMs': durationMs,
        if (error != null) 'error': error,
        if (detail != null) 'detail': detail,
      };
}

/// 单个书源的健康检查总结果
class SourceHealthResult {
  final String sourceUrl;
  final String sourceName;
  final SourceHealthStatus status;
  final List<SourceHealthStep> steps;
  final int totalMs;
  final String? failReason;

  const SourceHealthResult({
    required this.sourceUrl,
    required this.sourceName,
    required this.status,
    required this.steps,
    required this.totalMs,
    this.failReason,
  });

  bool get isFailed => status == SourceHealthStatus.failed;
}

/// 规则调试分步结果（表达式 → 匹配输出）
class SourceRuleStepResult {
  final String stage;
  final String field;
  final String? expression;
  final bool success;
  final String resultPreview;
  final String? error;
  final int? matchCount;
  final bool skipped;

  const SourceRuleStepResult({
    required this.stage,
    required this.field,
    this.expression,
    required this.success,
    this.resultPreview = '',
    this.error,
    this.matchCount,
    this.skipped = false,
  });
}
