import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudSyncTaskPage extends StatefulWidget {
  const CloudSyncTaskPage({super.key});

  @override
  State<CloudSyncTaskPage> createState() => _CloudSyncTaskPageState();
}

class _CloudSyncTaskPageState extends State<CloudSyncTaskPage> {
  final List<_CloudSyncTaskEntry> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTasks = prefs.getStringList('cloudSyncTasks') ?? [];
    final tasks = <_CloudSyncTaskEntry>[];
    for (final raw in rawTasks) {
      try {
        tasks.add(_CloudSyncTaskEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    if (!mounted) return;
    setState(() {
      _tasks
        ..clear()
        ..addAll(tasks);
    });
  }

  Future<void> _clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloudSyncTasks');
    if (!mounted) return;
    setState(_tasks.clear);
  }

  String _formatTime(int millisecondsSinceEpoch) {
    final time = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('云端同步任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadTasks,
          ),
          if (_tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空',
              onPressed: _clearTasks,
            ),
        ],
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '暂无云端同步任务\n\n主题被应用、保存或复制后，会在这里记录待同步项。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.action,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        task.themeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(task.time),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CloudSyncTaskEntry {
  final String action;
  final String themeName;
  final int time;

  _CloudSyncTaskEntry({
    required this.action,
    required this.themeName,
    required this.time,
  });

  factory _CloudSyncTaskEntry.fromJson(Map<String, dynamic> json) {
    return _CloudSyncTaskEntry(
      action: json['action'] as String? ?? '同步任务',
      themeName: json['themeName'] as String? ?? '未知主题',
      time: json['time'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
