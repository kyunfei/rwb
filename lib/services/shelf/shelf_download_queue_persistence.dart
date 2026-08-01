import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/shelf/shelf_download_task.dart';

class ShelfDownloadQueuePersistence {
  ShelfDownloadQueuePersistence._();
  static final ShelfDownloadQueuePersistence instance =
      ShelfDownloadQueuePersistence._();

  static const _fileName = 'shelf_download_queue.json';
  String? _filePath;

  Future<String> _path() async {
    if (_filePath != null) return _filePath!;
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/$_fileName';
    return _filePath!;
  }

  Future<ShelfDownloadQueueSnapshot> load() async {
    try {
      final file = File(await _path());
      if (!await file.exists()) {
        return const ShelfDownloadQueueSnapshot();
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ShelfDownloadQueueSnapshot.fromJson(json);
    } catch (e) {
      debugPrint('ShelfDownloadQueuePersistence.load: $e');
      return const ShelfDownloadQueueSnapshot();
    }
  }

  Future<void> save(ShelfDownloadQueueSnapshot snapshot) async {
    try {
      final file = File(await _path());
      await file.writeAsString(
        jsonEncode(snapshot.toJson()),
        flush: true,
      );
    } catch (e) {
      debugPrint('ShelfDownloadQueuePersistence.save: $e');
    }
  }
}
