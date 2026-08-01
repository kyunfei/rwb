// 顶栏配置类 - 参考 legado-main 的 TopBarConfig.Config
class TopBarConfig {
  String id;
  String name;
  bool isNight;
  bool isBuiltin;
  String style; // default, regular
  double cornerScale; // 0.0 ~ 3.0
  int? backgroundColor;
  String? wallpaperPath;
  int wallpaperAlpha; // 0 ~ 100
  int? tagBarColor;
  int tagBarAlpha; // 0 ~ 100
  int? tagSelectedColor;
  int tagSelectedAlpha; // 0 ~ 100
  bool expandFiltersByDefault;
  DateTime updatedAt;

  TopBarConfig({
    required this.id,
    required this.name,
    required this.isNight,
    this.isBuiltin = false,
    this.style = 'default',
    this.cornerScale = 1.0,
    this.backgroundColor,
    this.wallpaperPath,
    this.wallpaperAlpha = 100,
    this.tagBarColor,
    this.tagBarAlpha = 100,
    this.tagSelectedColor,
    this.tagSelectedAlpha = 100,
    this.expandFiltersByDefault = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  String toJson() {
    return '$id|$name|$isNight|$isBuiltin|$style|$cornerScale|${backgroundColor ?? 0}|${wallpaperPath ?? ''}|$wallpaperAlpha|${tagBarColor ?? 0}|$tagBarAlpha|${tagSelectedColor ?? 0}|$tagSelectedAlpha|$expandFiltersByDefault|${updatedAt.millisecondsSinceEpoch}';
  }

  factory TopBarConfig.fromJson(String json) {
    final parts = json.split('|');
    return TopBarConfig(
      id: parts[0],
      name: parts[1],
      isNight: parts[2] == 'true',
      isBuiltin: parts[3] == 'true',
      style: parts[4],
      cornerScale: double.parse(parts[5]),
      backgroundColor: int.parse(parts[6]) == 0 ? null : int.parse(parts[6]),
      wallpaperPath: parts[7].isEmpty ? null : parts[7],
      wallpaperAlpha: int.parse(parts[8]),
      tagBarColor: int.parse(parts[9]) == 0 ? null : int.parse(parts[9]),
      tagBarAlpha: int.parse(parts[10]),
      tagSelectedColor: int.parse(parts[11]) == 0 ? null : int.parse(parts[11]),
      tagSelectedAlpha: int.parse(parts[12]),
      expandFiltersByDefault: parts[13] == 'true',
      updatedAt: parts.length > 14 ? DateTime.fromMillisecondsSinceEpoch(int.parse(parts[14])) : DateTime.now(),
    );
  }

  TopBarConfig copy() {
    return TopBarConfig(
      id: id,
      name: name,
      isNight: isNight,
      isBuiltin: isBuiltin,
      style: style,
      cornerScale: cornerScale,
      backgroundColor: backgroundColor,
      wallpaperPath: wallpaperPath,
      wallpaperAlpha: wallpaperAlpha,
      tagBarColor: tagBarColor,
      tagBarAlpha: tagBarAlpha,
      tagSelectedColor: tagSelectedColor,
      tagSelectedAlpha: tagSelectedAlpha,
      expandFiltersByDefault: expandFiltersByDefault,
      updatedAt: updatedAt,
    );
  }
}

