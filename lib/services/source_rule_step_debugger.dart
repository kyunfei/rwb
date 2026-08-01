import '../models/book_source.dart';
import '../models/source_health.dart';
import 'app_logger.dart';
import 'source_engine/analyze_rule.dart';
import 'source_rule_step_logic.dart';

/// 对给定 HTML 按书源规则逐字段求值，产出分步结果（排查不出结果时用）。
class SourceRuleStepDebugger {
  /// 搜索页规则分步：先 bookList，再对首元素取各字段
  Future<List<SourceRuleStepResult>> debugSearchRules({
    required BookSource source,
    required String html,
    required String baseUrl,
    String? keyword,
  }) async {
    final rule = source.ruleSearch;
    final fields = searchRuleFields(
      bookList: rule?.bookList,
      name: rule?.name,
      author: rule?.author,
      bookUrl: rule?.bookUrl,
      coverUrl: rule?.coverUrl,
      kind: rule?.kind,
      lastChapter: rule?.lastChapter,
      intro: rule?.intro,
      wordCount: rule?.wordCount,
    );
    return _runListThenFields(
      stage: '搜索',
      fields: fields,
      html: html,
      baseUrl: baseUrl,
      source: source,
      listField: 'bookList',
      variables: {
        if (keyword != null) 'key': keyword,
        'page': 1,
      },
    );
  }

  Future<List<SourceRuleStepResult>> debugBookInfoRules({
    required BookSource source,
    required String html,
    required String baseUrl,
  }) async {
    final rule = source.ruleBookInfo;
    final fields = bookInfoRuleFields(
      init: rule?.init,
      name: rule?.name,
      author: rule?.author,
      coverUrl: rule?.coverUrl,
      intro: rule?.intro,
      kind: rule?.kind,
      lastChapter: rule?.lastChapter,
      tocUrl: rule?.tocUrl,
      wordCount: rule?.wordCount,
    );
    return _runPlainFields(
      stage: '详情',
      fields: fields,
      html: html,
      baseUrl: baseUrl,
      source: source,
    );
  }

  Future<List<SourceRuleStepResult>> debugTocRules({
    required BookSource source,
    required String html,
    required String baseUrl,
  }) async {
    final rule = source.ruleToc;
    final fields = tocRuleFields(
      chapterList: rule?.chapterList,
      chapterName: rule?.chapterName,
      chapterUrl: rule?.chapterUrl,
      isVolume: rule?.isVolume,
      nextTocUrl: rule?.nextTocUrl,
    );
    return _runListThenFields(
      stage: '目录',
      fields: fields,
      html: html,
      baseUrl: baseUrl,
      source: source,
      listField: 'chapterList',
    );
  }

  Future<List<SourceRuleStepResult>> debugContentRules({
    required BookSource source,
    required String html,
    required String baseUrl,
  }) async {
    final rule = source.ruleContent;
    final fields = contentRuleFields(
      content: rule?.content,
      title: rule?.title,
      nextContentUrl: rule?.nextContentUrl,
    );
    return _runPlainFields(
      stage: '正文',
      fields: fields,
      html: html,
      baseUrl: baseUrl,
      source: source,
    );
  }

  Future<List<SourceRuleStepResult>> _runPlainFields({
    required String stage,
    required List<SourceRuleFieldSpec> fields,
    required String html,
    required String baseUrl,
    required BookSource source,
  }) async {
    final results = <SourceRuleStepResult>[];
    final analyzer = _createAnalyzer(source, html, baseUrl);

    for (final spec in fields) {
      results.add(await _evalField(stage, spec, analyzer));
    }
    return results;
  }

  Future<List<SourceRuleStepResult>> _runListThenFields({
    required String stage,
    required List<SourceRuleFieldSpec> fields,
    required String html,
    required String baseUrl,
    required BookSource source,
    required String listField,
    Map<String, dynamic> variables = const {},
  }) async {
    final results = <SourceRuleStepResult>[];
    final analyzer = _createAnalyzer(source, html, baseUrl);
    for (final entry in variables.entries) {
      analyzer.putVariable(entry.key, entry.value);
    }

    final listSpec = fields.firstWhere(
      (f) => f.field == listField,
      orElse: () => SourceRuleFieldSpec(field: listField, isList: true),
    );
    final listResult = await _evalField(stage, listSpec, analyzer);
    results.add(listResult);

    Object? firstElement;
    if (listResult.success && !listResult.skipped) {
      try {
        var rule = listSpec.expression ?? '';
        if (rule.startsWith('-') || rule.startsWith('+')) {
          rule = rule.substring(1);
        }
        final elements = await analyzer.getElementsAsync(rule);
        if (elements.isNotEmpty) {
          firstElement = elements.first;
        }
      } catch (e, st) {
        AppLogger.instance.error(
          LogCategory.parse,
          '规则调试取列表首元素失败: $stage.$listField',
          detail: '$e\n$st',
        );
      }
    }

    for (final spec in fields) {
      if (spec.field == listField) continue;
      if (firstElement == null) {
        if (spec.expression == null || spec.expression!.trim().isEmpty) {
          results.add(buildSkippedStep(stage, spec.field));
        } else {
          results.add(buildStepResult(
            stage: stage,
            field: spec.field,
            expression: spec.expression,
            success: false,
            error: '列表为空，无法提取字段',
          ));
        }
        continue;
      }
      final itemAnalyzer = _createAnalyzer(source, firstElement, baseUrl);
      for (final entry in variables.entries) {
        itemAnalyzer.putVariable(entry.key, entry.value);
      }
      results.add(await _evalField(stage, spec, itemAnalyzer));
    }
    return results;
  }

  AnalyzeRule _createAnalyzer(
    BookSource source,
    dynamic content,
    String baseUrl,
  ) {
    return AnalyzeRule()
      ..setContent(content, baseUrl: baseUrl)
      ..setSourceEngine(source.engineType)
      ..setSourceInfo(source.toJson());
  }

  Future<SourceRuleStepResult> _evalField(
    String stage,
    SourceRuleFieldSpec spec,
    AnalyzeRule analyzer,
  ) async {
    final expr = spec.expression?.trim();
    if (expr == null || expr.isEmpty) {
      return buildSkippedStep(stage, spec.field);
    }
    try {
      if (spec.isList) {
        var rule = expr;
        if (rule.startsWith('-') || rule.startsWith('+')) {
          rule = rule.substring(1);
        }
        final elements = await analyzer.getElementsAsync(rule);
        return buildStepResult(
          stage: stage,
          field: spec.field,
          expression: expr,
          success: elements.isNotEmpty,
          value: elements,
          matchCount: elements.length,
          error: elements.isEmpty ? '未匹配到任何元素' : null,
        );
      }
      final value = await analyzer.getStringAsync(expr);
      final empty = value == null || value.trim().isEmpty;
      return buildStepResult(
        stage: stage,
        field: spec.field,
        expression: expr,
        success: !empty,
        value: value,
        error: empty ? '结果为空' : null,
      );
    } catch (e, st) {
      AppLogger.instance.error(
        LogCategory.parse,
        '规则调试失败: $stage.${spec.field}',
        detail: '表达式: $expr\n$e\n$st',
      );
      return buildStepResult(
        stage: stage,
        field: spec.field,
        expression: expr,
        success: false,
        error: e.toString(),
      );
    }
  }
}
