class NavigationBarConfig {
  String id;
  String name;
  bool isNight;
  bool isBuiltin;
  String layoutMode; // floating, standard, sidebar
  String effectMode; // solid, glass, frosted
  int opacity;
  int? borderColor;
  int borderAlpha;
  String? wallpaperPath;
  String? sidebarBackgroundPath;
  String sidebarGravity; // start, end
  Map<String, String> icons; // 自定义图标
  DateTime updatedAt;

  NavigationBarConfig({
    required this.id,
    required this.name,
    required this.isNight,
    this.isBuiltin = false,
    this.layoutMode = 'floating',
    this.effectMode = 'glass',
    this.opacity = 72,
    this.borderColor,
    this.borderAlpha = 100,
    this.wallpaperPath,
    this.sidebarBackgroundPath,
    this.sidebarGravity = 'start',
    Map<String, String>? icons,
    DateTime? updatedAt,
  }) : icons = icons ?? {}, updatedAt = updatedAt ?? DateTime.now();

  String toJson() {
    final iconsJson = icons.entries.map((e) => '${e.key}=${e.value}').join(',');
    return '$id|$name|$isNight|$isBuiltin|$layoutMode|$effectMode|$opacity|${borderColor ?? 0}|$borderAlpha|${wallpaperPath ?? ''}|${sidebarBackgroundPath ?? ''}|$sidebarGravity|$iconsJson|${updatedAt.millisecondsSinceEpoch}';
  }

  factory NavigationBarConfig.fromJson(String json) {
    final parts = json.split('|');
    final icons = <String, String>{};
    if (parts.length > 12 && parts[12].isNotEmpty) {
      for (final entry in parts[12].split(',')) {
        if (entry.contains('=')) {
          final kv = entry.split('=');
          icons[kv[0]] = kv[1];
        }
      }
    }
    return NavigationBarConfig(
      id: parts[0],
      name: parts[1],
      isNight: parts[2] == 'true',
      isBuiltin: parts[3] == 'true',
      layoutMode: parts[4],
      effectMode: parts[5],
      opacity: int.parse(parts[6]),
      borderColor: int.parse(parts[7]) == 0 ? null : int.parse(parts[7]),
      borderAlpha: int.parse(parts[8]),
      wallpaperPath: parts[9].isEmpty ? null : parts[9],
      sidebarBackgroundPath: parts[10].isEmpty ? null : parts[10],
      sidebarGravity: parts[11],
      icons: icons,
      updatedAt: parts.length > 13 ? DateTime.fromMillisecondsSinceEpoch(int.parse(parts[13])) : DateTime.now(),
    );
  }

  NavigationBarConfig copy() {
    return NavigationBarConfig(
      id: id,
      name: name,
      isNight: isNight,
      isBuiltin: isBuiltin,
      layoutMode: layoutMode,
      effectMode: effectMode,
      opacity: opacity,
      borderColor: borderColor,
      borderAlpha: borderAlpha,
      wallpaperPath: wallpaperPath,
      sidebarBackgroundPath: sidebarBackgroundPath,
      sidebarGravity: sidebarGravity,
      icons: Map.from(icons),
      updatedAt: updatedAt,
    );
  }
}
