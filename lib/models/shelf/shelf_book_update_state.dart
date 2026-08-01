class ShelfBookUpdateState {
  final bool hasNewChapters;
  final int newChapterCount;
  final String? lastError;
  final DateTime? lastCheckedAt;
  final DateTime? lastSuccessAt;

  const ShelfBookUpdateState({
    this.hasNewChapters = false,
    this.newChapterCount = 0,
    this.lastError,
    this.lastCheckedAt,
    this.lastSuccessAt,
  });

  ShelfBookUpdateState copyWith({
    bool? hasNewChapters,
    int? newChapterCount,
    String? lastError,
    bool clearError = false,
    DateTime? lastCheckedAt,
    DateTime? lastSuccessAt,
  }) {
    return ShelfBookUpdateState(
      hasNewChapters: hasNewChapters ?? this.hasNewChapters,
      newChapterCount: newChapterCount ?? this.newChapterCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'hasNewChapters': hasNewChapters,
        'newChapterCount': newChapterCount,
        if (lastError != null) 'lastError': lastError,
        if (lastCheckedAt != null)
          'lastCheckedAt': lastCheckedAt!.toIso8601String(),
        if (lastSuccessAt != null)
          'lastSuccessAt': lastSuccessAt!.toIso8601String(),
      };

  factory ShelfBookUpdateState.fromJson(Map<String, dynamic> json) {
    return ShelfBookUpdateState(
      hasNewChapters: json['hasNewChapters'] as bool? ?? false,
      newChapterCount: json['newChapterCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      lastCheckedAt: json['lastCheckedAt'] != null
          ? DateTime.tryParse(json['lastCheckedAt'] as String)
          : null,
      lastSuccessAt: json['lastSuccessAt'] != null
          ? DateTime.tryParse(json['lastSuccessAt'] as String)
          : null,
    );
  }
}
