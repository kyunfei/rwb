import 'dart:convert';

/// 发现/书城分类数据结构
class ExploreCategory {
  final String title;
  final String url;
  final List<ExploreCategory> children;

  const ExploreCategory({
    required this.title,
    required this.url,
    this.children = const [],
  });
}

/// 解析 exploreUrl 为分类列表
/// 支持以下格式：
/// - `分类名称::url`（标准格式）
/// - `分类名称@url`
/// - `分类名称::url&&分类名称2::url2`（多分类格式）
/// - JSON 格式的 exploreUrl
List<ExploreCategory> parseExploreKinds(String? exploreUrl) {
  if (exploreUrl == null || exploreUrl.isEmpty) return [];

  final categories = <ExploreCategory>[];

  // 尝试 JSON 格式
  try {
    final decoded = jsonDecode(exploreUrl);
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          final title = item['title']?.toString() ?? '';
          final url = item['url']?.toString() ?? '';
          if (title.isNotEmpty && url.isNotEmpty) {
            categories.add(ExploreCategory(title: title, url: url));
          }
        }
      }
      return categories;
    } else if (decoded is Map) {
      decoded.forEach((key, value) {
        if (value is List) {
          final children = <ExploreCategory>[];
          for (final child in value) {
            if (child is Map) {
              final cTitle = child['title']?.toString() ?? '';
              final cUrl = child['url']?.toString() ?? '';
              if (cTitle.isNotEmpty && cUrl.isNotEmpty) {
                children.add(ExploreCategory(title: cTitle, url: cUrl));
              }
            }
          }
          categories.add(ExploreCategory(
            title: key.toString(),
            url: '',
            children: children,
          ));
        } else if (value is String) {
          categories.add(ExploreCategory(title: key.toString(), url: value));
        }
      });
      return categories;
    }
  } catch (_) {
    // 不是 JSON，继续用文本格式解析
  }

  // 文本格式解析
  final lines = exploreUrl.split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    // 处理 && 分隔的多分类
    final segments = line.split('&&');
    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      // 支持 :: 格式
      if (trimmed.contains('::')) {
        final parts = trimmed.split('::');
        if (parts.length >= 2) {
          categories.add(ExploreCategory(
            title: parts[0].trim(),
            url: parts.sublist(1).join('::').trim(),
          ));
        }
      }
      // 支持 @ 格式
      else if (trimmed.contains('@')) {
        final parts = trimmed.split('@');
        if (parts.length >= 2) {
          categories.add(ExploreCategory(
            title: parts[0].trim(),
            url: parts.sublist(1).join('@').trim(),
          ));
        }
      }
    }
  }

  return categories;
}

/// 将带 children 的分类树展平为可点击的叶子分类（有 URL 的项）
List<ExploreCategory> flattenExploreCategories(
  List<ExploreCategory> categories,
) {
  final result = <ExploreCategory>[];
  for (final category in categories) {
    if (category.children.isNotEmpty) {
      result.addAll(flattenExploreCategories(category.children));
    } else if (category.url.isNotEmpty) {
      result.add(category);
    }
  }
  return result;
}
