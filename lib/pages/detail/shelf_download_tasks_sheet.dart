import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../models/shelf/shelf_download_task.dart';
import '../../services/shelf/shelf_download_queue_service.dart';
import '../../utils/design_tokens.dart';

class ShelfDownloadTasksSheet extends StatelessWidget {
  final Book book;

  const ShelfDownloadTasksSheet({super.key, required this.book});

  static Future<void> show(BuildContext context, Book book) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ShelfDownloadTasksSheet(book: book),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Consumer<ShelfDownloadQueueService>(
          builder: (context, queue, _) {
            final tasks = queue.tasksForBook(book.bookUrl);
            return Material(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacingLg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '离线下载任务',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text('并发 ${queue.concurrency}'),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: tasks.isEmpty
                        ? const Center(child: Text('暂无下载任务'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              return _TaskTile(task: tasks[index]);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  final ShelfDownloadTask task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final queue = context.read<ShelfDownloadQueueService>();
    final progress = task.progress;
    return ListTile(
      title: Text(
        '${task.rangeMode.name} · ${task.completedInRange}/${task.totalInRange}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          if (task.lastError != null)
            Text(
              task.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          if (task.failedChapters.isNotEmpty)
            Text(
              '失败 ${task.failedChapters.length} 章',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (task.status == ShelfDownloadTaskStatus.running ||
              task.status == ShelfDownloadTaskStatus.pending)
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: '暂停',
              onPressed: () => queue.pauseTask(task.id),
            ),
          if (task.status == ShelfDownloadTaskStatus.paused)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '继续',
              onPressed: () => queue.resumeTask(task.id),
            ),
          if (task.failedChapters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重试失败章节',
              onPressed: () => queue.retryFailedChapters(task.id),
            ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: '取消',
            onPressed: () => queue.cancelTask(task.id),
          ),
        ],
      ),
    );
  }
}
