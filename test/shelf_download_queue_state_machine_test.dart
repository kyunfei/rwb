import 'package:flutter_test/flutter_test.dart';
import 'package:mr/models/shelf/shelf_download_task.dart';

void main() {
  group('ShelfDownloadQueueStateMachine', () {
    test('normalizeOnColdStart pauses running tasks', () {
      expect(
        ShelfDownloadQueueStateMachine.normalizeOnColdStart(
          ShelfDownloadTaskStatus.running,
        ),
        ShelfDownloadTaskStatus.paused,
      );
      expect(
        ShelfDownloadQueueStateMachine.normalizeOnColdStart(
          ShelfDownloadTaskStatus.pending,
        ),
        ShelfDownloadTaskStatus.pending,
      );
    });

    test('canTransition enforces valid edges', () {
      expect(
        ShelfDownloadQueueStateMachine.canTransition(
          ShelfDownloadTaskStatus.pending,
          ShelfDownloadTaskStatus.running,
        ),
        isTrue,
      );
      expect(
        ShelfDownloadQueueStateMachine.canTransition(
          ShelfDownloadTaskStatus.completed,
          ShelfDownloadTaskStatus.running,
        ),
        isTrue,
      );
      expect(
        ShelfDownloadQueueStateMachine.canTransition(
          ShelfDownloadTaskStatus.pending,
          ShelfDownloadTaskStatus.completed,
        ),
        isFalse,
      );
    });

    test('pendingChapterIndices skips completed and volumes', () {
      final now = DateTime(2024, 1, 1);
      final task = ShelfDownloadTask(
        id: 't1',
        bookUrl: 'b1',
        bookName: 'book',
        rangeMode: ShelfDownloadRangeMode.all,
        rangeStartIndex: 0,
        rangeEndIndex: 2,
        chapters: const [
          ShelfDownloadChapterRef(
            index: 0,
            title: '卷一',
            isVolume: true,
          ),
          ShelfDownloadChapterRef(
            index: 1,
            title: '第一章',
            url: 'https://a/1',
          ),
          ShelfDownloadChapterRef(
            index: 2,
            title: '第二章',
            url: 'https://a/2',
          ),
        ],
        completedIndices: {1},
        status: ShelfDownloadTaskStatus.paused,
        createdAt: now,
        updatedAt: now,
      );
      final pending = ShelfDownloadQueueStateMachine.pendingChapterIndices(task);
      expect(pending, [2]);
    });

    test('progress reflects completed chapters in range', () {
      final now = DateTime(2024, 1, 1);
      final task = ShelfDownloadTask(
        id: 't1',
        bookUrl: 'b1',
        bookName: 'book',
        rangeMode: ShelfDownloadRangeMode.custom,
        rangeStartIndex: 1,
        rangeEndIndex: 3,
        chapters: const [
          ShelfDownloadChapterRef(
            index: 1,
            title: '第一章',
            url: 'https://a/1',
          ),
          ShelfDownloadChapterRef(
            index: 2,
            title: '第二章',
            url: 'https://a/2',
          ),
          ShelfDownloadChapterRef(
            index: 3,
            title: '第三章',
            url: 'https://a/3',
          ),
        ],
        completedIndices: {1, 2},
        status: ShelfDownloadTaskStatus.running,
        createdAt: now,
        updatedAt: now,
      );
      expect(task.totalInRange, 3);
      expect(task.completedInRange, 2);
      expect(task.progress, closeTo(2 / 3, 0.001));
    });
  });
}
