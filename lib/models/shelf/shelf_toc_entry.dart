/// 目录快照条目（仅用于更新检测比对，不含正文）
class ShelfTocEntry {
  final String? url;
  final String title;
  final bool isVolume;

  const ShelfTocEntry({
    required this.title,
    this.url,
    this.isVolume = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (url != null) 'url': url,
        'isVolume': isVolume,
      };

  factory ShelfTocEntry.fromJson(Map<String, dynamic> json) => ShelfTocEntry(
        title: json['title'] as String? ?? '',
        url: json['url'] as String?,
        isVolume: json['isVolume'] as bool? ?? false,
      );
}
