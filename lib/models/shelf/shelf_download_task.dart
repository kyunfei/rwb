enum ShelfDownloadRangeMode {
  all,
  fromCurrent,
  custom,
}

enum ShelfDownloadTaskStatus {
  pending,
  running,
  paused,
  completed,
  cancelled,
  failed,
}

class ShelfDownloadChapterRef {
  final int index;
  final String title;
  final String? url;
  final bool isVolume;

  const ShelfDownloadChapterRef({
    required this.index,
    required this.title,
    this.url,
    this.isVolume = false,
  });

  bool get isReadable =>
      !isVolume && url != null && url!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        if (url != null) 'url': url,
        'isVolume': isVolume,
      };

  factory ShelfDownloadChapterRef.fromJson(Map<String, dynamic> json) {
    return ShelfDownloadChapterRef(
      index: json['index'] as int,
      title: json['title'] as String? ?? '',
      url: json['url'] as String?,
      isVolume: json['isVolume'] as bool? ?? false,
    );
  }
}

class ShelfDownloadFailedChapter {
  final int index;
  final String error;

  const ShelfDownloadFailedChapter({required this.index, required this.error});

  Map<String, dynamic> toJson() => {'index': index, 'error': error};

  factory ShelfDownloadFailedChapter.fromJson(Map<String, dynamic> json) {
    return ShelfDownloadFailedChapter(
      index: json['index'] as int,
      error: json['error'] as String? ?? '',
    );
  }
}

class ShelfDownloadTask {
  final String id;
  final String bookUrl;
  final String bookName;
  final ShelfDownloadRangeMode rangeMode;
  final int rangeStartIndex;
  final int rangeEndIndex;
  final List<ShelfDownloadChapterRef> chapters;
  final Set<int> completedIndices;
  final List<ShelfDownloadFailedChapter> failedChapters;
  final ShelfDownloadTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;

  const ShelfDownloadTask({
    required this.id,
    required this.bookUrl,
    required this.bookName,
    required this.rangeMode,
    required this.rangeStartIndex,
    required this.rangeEndIndex,
    required this.chapters,
    this.completedIndices = const {},
    this.failedChapters = const [],
    this.status = ShelfDownloadTaskStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  int get totalInRange {
    return chapters
        .where(
          (c) =>
              c.index >= rangeStartIndex &&
              c.index <= rangeEndIndex &&
              c.isReadable,
        )
        .length;
  }

  int get completedInRange {
    return completedIndices
        .where((i) => i >= rangeStartIndex && i <= rangeEndIndex)
        .length;
  }

  double get progress {
    final total = totalInRange;
    if (total <= 0) return status == ShelfDownloadTaskStatus.completed ? 1 : 0;
    return completedInRange / total;
  }

  ShelfDownloadTask copyWith({
    Set<int>? completedIndices,
    List<ShelfDownloadFailedChapter>? failedChapters,
    ShelfDownloadTaskStatus? status,
    DateTime? updatedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return ShelfDownloadTask(
      id: id,
      bookUrl: bookUrl,
      bookName: bookName,
      rangeMode: rangeMode,
      rangeStartIndex: rangeStartIndex,
      rangeEndIndex: rangeEndIndex,
      chapters: chapters,
      completedIndices: completedIndices ?? this.completedIndices,
      failedChapters: failedChapters ?? this.failedChapters,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookUrl': bookUrl,
        'bookName': bookName,
        'rangeMode': rangeMode.index,
        'rangeStartIndex': rangeStartIndex,
        'rangeEndIndex': rangeEndIndex,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'completedIndices': completedIndices.toList(),
        'failedChapters': failedChapters.map((e) => e.toJson()).toList(),
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (lastError != null) 'lastError': lastError,
      };

  factory ShelfDownloadTask.fromJson(Map<String, dynamic> json) {
    return ShelfDownloadTask(
      id: json['id'] as String,
      bookUrl: json['bookUrl'] as String,
      bookName: json['bookName'] as String? ?? '',
      rangeMode: ShelfDownloadRangeMode.values[json['rangeMode'] as int? ?? 0],
      rangeStartIndex: json['rangeStartIndex'] as int? ?? 0,
      rangeEndIndex: json['rangeEndIndex'] as int? ?? 0,
      chapters: (json['chapters'] as List<dynamic>)
          .map(
            (e) => ShelfDownloadChapterRef.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      completedIndices:
          (json['completedIndices'] as List<dynamic>? ?? []).cast<int>().toSet(),
      failedChapters: (json['failedChapters'] as List<dynamic>? ?? [])
          .map(
            (e) =>
                ShelfDownloadFailedChapter.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      status: ShelfDownloadTaskStatus.values[json['status'] as int? ?? 0],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastError: json['lastError'] as String?,
    );
  }
}

class ShelfDownloadQueueSnapshot {
  final int version;
  final int concurrency;
  final List<ShelfDownloadTask> tasks;

  const ShelfDownloadQueueSnapshot({
    this.version = 1,
    this.concurrency = 2,
    this.tasks = const [],
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'concurrency': concurrency,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory ShelfDownloadQueueSnapshot.fromJson(Map<String, dynamic> json) {
    return ShelfDownloadQueueSnapshot(
      version: json['version'] as int? ?? 1,
      concurrency: json['concurrency'] as int? ?? 2,
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((e) => ShelfDownloadTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 下载队列状态机（纯逻辑，便于单测）
class ShelfDownloadQueueStateMachine {
  ShelfDownloadQueueStateMachine._();

  static bool canTransition(
    ShelfDownloadTaskStatus from,
    ShelfDownloadTaskStatus to,
  ) {
    if (from == to) return true;
    switch (from) {
      case ShelfDownloadTaskStatus.pending:
        return to == ShelfDownloadTaskStatus.running ||
            to == ShelfDownloadTaskStatus.cancelled;
      case ShelfDownloadTaskStatus.running:
        return to == ShelfDownloadTaskStatus.paused ||
            to == ShelfDownloadTaskStatus.completed ||
            to == ShelfDownloadTaskStatus.cancelled ||
            to == ShelfDownloadTaskStatus.failed;
      case ShelfDownloadTaskStatus.paused:
        return to == ShelfDownloadTaskStatus.running ||
            to == ShelfDownloadTaskStatus.cancelled;
      case ShelfDownloadTaskStatus.completed:
      case ShelfDownloadTaskStatus.cancelled:
      case ShelfDownloadTaskStatus.failed:
        return to == ShelfDownloadTaskStatus.pending ||
            to == ShelfDownloadTaskStatus.running;
    }
  }

  static ShelfDownloadTaskStatus normalizeOnColdStart(
    ShelfDownloadTaskStatus persisted,
  ) {
    if (persisted == ShelfDownloadTaskStatus.running) {
      return ShelfDownloadTaskStatus.paused;
    }
    return persisted;
  }

  static List<int> pendingChapterIndices(ShelfDownloadTask task) {
    final result = <int>[];
    for (final ref in task.chapters) {
      if (ref.index < task.rangeStartIndex || ref.index > task.rangeEndIndex) {
        continue;
      }
      if (!ref.isReadable) continue;
      if (task.completedIndices.contains(ref.index)) continue;
      result.add(ref.index);
    }
    result.sort();
    return result;
  }
}
