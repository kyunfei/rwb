/// 书源订阅地址记录（记住远程 JSON 地址，支持一键更新）
class SourceSubscription {
  final String url;
  final String? name;
  final int lastUpdateTime;
  final int lastAdded;
  final int lastUpdated;
  final int lastUnchanged;
  final String? lastError;

  const SourceSubscription({
    required this.url,
    this.name,
    this.lastUpdateTime = 0,
    this.lastAdded = 0,
    this.lastUpdated = 0,
    this.lastUnchanged = 0,
    this.lastError,
  });

  SourceSubscription copyWith({
    String? url,
    String? name,
    int? lastUpdateTime,
    int? lastAdded,
    int? lastUpdated,
    int? lastUnchanged,
    String? lastError,
    bool clearError = false,
  }) {
    return SourceSubscription(
      url: url ?? this.url,
      name: name ?? this.name,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      lastAdded: lastAdded ?? this.lastAdded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastUnchanged: lastUnchanged ?? this.lastUnchanged,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  factory SourceSubscription.fromJson(Map<String, dynamic> json) {
    return SourceSubscription(
      url: json['url'] as String? ?? '',
      name: json['name'] as String?,
      lastUpdateTime: (json['lastUpdateTime'] as num?)?.toInt() ?? 0,
      lastAdded: (json['lastAdded'] as num?)?.toInt() ?? 0,
      lastUpdated: (json['lastUpdated'] as num?)?.toInt() ?? 0,
      lastUnchanged: (json['lastUnchanged'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (name != null) 'name': name,
        'lastUpdateTime': lastUpdateTime,
        'lastAdded': lastAdded,
        'lastUpdated': lastUpdated,
        'lastUnchanged': lastUnchanged,
        if (lastError != null) 'lastError': lastError,
      };
}
