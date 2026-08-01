import 'package:flutter/material.dart';

/// 主题配置类 - 参考 legado-main 的 ThemeConfig.Config
class ThemeConfig {
  String id;
  String name;
  bool isNight;
  bool isBuiltin;
  Color primaryColor;
  Color accentColor;
  Color backgroundColor;
  Color navBarColor;
  // 图片设置
  String? mainBgImage;
  int bgImageBlur;
  String? bookInfoBgImage;
  String? panelBgImage;
  String panelBgMode; // crop, fit
  // 界面设置
  double cornerScale;
  int layoutAlpha;
  Color? panelBorderColor;
  int panelBorderAlpha;
  bool searchFollow;
  bool replyFollow;
  // 字体设置
  int fontScale;
  String? uiFont;
  String? titleFont;
  // 时间戳
  DateTime updatedAt;

  ThemeConfig({
    required this.id,
    required this.name,
    required this.isNight,
    required this.isBuiltin,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    this.navBarColor = const Color(0xFFF5F5F5),
    this.mainBgImage,
    this.bgImageBlur = 0,
    this.bookInfoBgImage,
    this.panelBgImage,
    this.panelBgMode = 'crop',
    this.cornerScale = 1.0,
    this.layoutAlpha = 100,
    this.panelBorderColor,
    this.panelBorderAlpha = 100,
    this.searchFollow = false,
    this.replyFollow = false,
    this.fontScale = 10,
    this.uiFont,
    this.titleFont,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  ThemeConfig copy() {
    return ThemeConfig(
      id: id,
      name: name,
      isNight: isNight,
      isBuiltin: isBuiltin,
      primaryColor: primaryColor,
      accentColor: accentColor,
      backgroundColor: backgroundColor,
      navBarColor: navBarColor,
      mainBgImage: mainBgImage,
      bgImageBlur: bgImageBlur,
      bookInfoBgImage: bookInfoBgImage,
      panelBgImage: panelBgImage,
      panelBgMode: panelBgMode,
      cornerScale: cornerScale,
      layoutAlpha: layoutAlpha,
      panelBorderColor: panelBorderColor,
      panelBorderAlpha: panelBorderAlpha,
      searchFollow: searchFollow,
      replyFollow: replyFollow,
      fontScale: fontScale,
      uiFont: uiFont,
      titleFont: titleFont,
      updatedAt: updatedAt,
    );
  }

  String toJson() {
    return '$id|$name|$isNight|$isBuiltin|${primaryColor.toARGB32()}|${accentColor.toARGB32()}|${backgroundColor.toARGB32()}|${navBarColor.toARGB32()}|${mainBgImage ?? ''}|$bgImageBlur|${bookInfoBgImage ?? ''}|${panelBgImage ?? ''}|$panelBgMode|$cornerScale|$layoutAlpha|${panelBorderColor?.toARGB32() ?? 0}|$panelBorderAlpha|$searchFollow|$replyFollow|$fontScale|${uiFont ?? ''}|${titleFont ?? ''}|${updatedAt.millisecondsSinceEpoch}';
  }

  factory ThemeConfig.fromJson(String json) {
    final parts = json.split('|');
    if (parts.length < 8) {
      throw const FormatException('主题配置字段不足');
    }
    String valueAt(int index, [String fallback = '']) {
      return index < parts.length ? parts[index] : fallback;
    }

    int intAt(int index, int fallback) {
      return int.tryParse(valueAt(index)) ?? fallback;
    }

    double doubleAt(int index, double fallback) {
      return double.tryParse(valueAt(index)) ?? fallback;
    }

    return ThemeConfig(
      id: parts[0],
      name: parts[1],
      isNight: parts[2] == 'true',
      isBuiltin: parts[3] == 'true',
      primaryColor: Color(int.parse(parts[4])),
      accentColor: Color(int.parse(parts[5])),
      backgroundColor: Color(int.parse(parts[6])),
      navBarColor: Color(int.parse(parts[7])),
      mainBgImage: valueAt(8).isEmpty ? null : valueAt(8),
      bgImageBlur: intAt(9, 0).clamp(0, 25),
      bookInfoBgImage: valueAt(10).isEmpty ? null : valueAt(10),
      panelBgImage: valueAt(11).isEmpty ? null : valueAt(11),
      panelBgMode: valueAt(12, 'crop') == 'fit' ? 'fit' : 'crop',
      cornerScale: doubleAt(13, 1).clamp(0, 3),
      layoutAlpha: intAt(14, 100).clamp(0, 100),
      panelBorderColor: intAt(15, 0) == 0
          ? null
          : Color(intAt(15, 0)),
      panelBorderAlpha: intAt(16, 100).clamp(0, 100),
      searchFollow: valueAt(17) == 'true',
      replyFollow: valueAt(18) == 'true',
      fontScale: intAt(19, 10).clamp(8, 16),
      uiFont: valueAt(20).isEmpty ? null : valueAt(20),
      titleFont: valueAt(21).isEmpty ? null : valueAt(21),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        intAt(22, DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}

