import '../models/source_health.dart';

/// 规则字段描述（阶段内字段顺序）
class SourceRuleFieldSpec {
  final String field;
  final String? expression;
  final bool isList;

  const SourceRuleFieldSpec({
    required this.field,
    this.expression,
    this.isList = false,
  });
}

/// 截断预览文本，避免日志/UI 被巨型 HTML 撑爆
String previewRuleOutput(Object? value, {int maxChars = 500}) {
  if (value == null) return '<null>';
  String text;
  if (value is List) {
    text = '列表(${value.length}): ${value.take(3).map(_stringify).join(' | ')}';
    if (value.length > 3) text += ' …';
  } else {
    text = _stringify(value);
  }
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}…(共${text.length}字)';
}

String _stringify(Object? value) {
  if (value == null) return '<null>';
  final s = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? '<空>' : s;
}

/// 组装搜索阶段字段规格
List<SourceRuleFieldSpec> searchRuleFields({
  String? bookList,
  String? name,
  String? author,
  String? bookUrl,
  String? coverUrl,
  String? kind,
  String? lastChapter,
  String? intro,
  String? wordCount,
}) {
  return [
    SourceRuleFieldSpec(field: 'bookList', expression: bookList, isList: true),
    SourceRuleFieldSpec(field: 'name', expression: name),
    SourceRuleFieldSpec(field: 'author', expression: author),
    SourceRuleFieldSpec(field: 'bookUrl', expression: bookUrl),
    SourceRuleFieldSpec(field: 'coverUrl', expression: coverUrl),
    SourceRuleFieldSpec(field: 'kind', expression: kind),
    SourceRuleFieldSpec(field: 'lastChapter', expression: lastChapter),
    SourceRuleFieldSpec(field: 'intro', expression: intro),
    SourceRuleFieldSpec(field: 'wordCount', expression: wordCount),
  ];
}

List<SourceRuleFieldSpec> bookInfoRuleFields({
  String? init,
  String? name,
  String? author,
  String? coverUrl,
  String? intro,
  String? kind,
  String? lastChapter,
  String? tocUrl,
  String? wordCount,
}) {
  return [
    SourceRuleFieldSpec(field: 'init', expression: init),
    SourceRuleFieldSpec(field: 'name', expression: name),
    SourceRuleFieldSpec(field: 'author', expression: author),
    SourceRuleFieldSpec(field: 'coverUrl', expression: coverUrl),
    SourceRuleFieldSpec(field: 'intro', expression: intro),
    SourceRuleFieldSpec(field: 'kind', expression: kind),
    SourceRuleFieldSpec(field: 'lastChapter', expression: lastChapter),
    SourceRuleFieldSpec(field: 'tocUrl', expression: tocUrl),
    SourceRuleFieldSpec(field: 'wordCount', expression: wordCount),
  ];
}

List<SourceRuleFieldSpec> tocRuleFields({
  String? chapterList,
  String? chapterName,
  String? chapterUrl,
  String? isVolume,
  String? nextTocUrl,
}) {
  return [
    SourceRuleFieldSpec(
        field: 'chapterList', expression: chapterList, isList: true),
    SourceRuleFieldSpec(field: 'chapterName', expression: chapterName),
    SourceRuleFieldSpec(field: 'chapterUrl', expression: chapterUrl),
    SourceRuleFieldSpec(field: 'isVolume', expression: isVolume),
    SourceRuleFieldSpec(field: 'nextTocUrl', expression: nextTocUrl),
  ];
}

List<SourceRuleFieldSpec> contentRuleFields({
  String? content,
  String? title,
  String? nextContentUrl,
}) {
  return [
    SourceRuleFieldSpec(field: 'content', expression: content),
    SourceRuleFieldSpec(field: 'title', expression: title),
    SourceRuleFieldSpec(field: 'nextContentUrl', expression: nextContentUrl),
  ];
}

/// 空规则标记为 skipped；有表达式但结果空 → success=false（由调用方决定）
SourceRuleStepResult buildSkippedStep(String stage, String field) {
  return SourceRuleStepResult(
    stage: stage,
    field: field,
    expression: null,
    success: true,
    resultPreview: '<未配置>',
    skipped: true,
  );
}

SourceRuleStepResult buildStepResult({
  required String stage,
  required String field,
  required String? expression,
  required bool success,
  Object? value,
  String? error,
  int? matchCount,
}) {
  return SourceRuleStepResult(
    stage: stage,
    field: field,
    expression: expression,
    success: success,
    resultPreview: error != null ? '' : previewRuleOutput(value),
    error: error,
    matchCount: matchCount,
  );
}

/// 格式化为调试日志行
List<String> formatRuleStepLogs(SourceRuleStepResult step) {
  if (step.skipped) {
    return ['┌规则 ${step.stage}.${step.field}', '└未配置，跳过'];
  }
  final lines = <String>[
    '┌规则 ${step.stage}.${step.field}',
    '├表达式: ${step.expression ?? "<空>"}',
  ];
  if (step.error != null) {
    lines.add('└失败: ${step.error}');
  } else if (step.matchCount != null) {
    lines.add('└匹配: ${step.matchCount} 项 → ${step.resultPreview}');
  } else {
    lines.add('└结果: ${step.resultPreview}');
  }
  return lines;
}
