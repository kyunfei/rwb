import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/shelf/shelf_toc_entry.dart';

/// 每本书的目录快照（用于更新检测）
class ShelfTocSnapshotStore {
  ShelfTocSnapshotStore._();
  static final ShelfTocSnapshotStore instance = ShelfTocSnapshotStore._();

  static const _folderName = 'shelf_toc_snapshots';
  String? _rootPath;

  Future<void> _ensureRoot() async {
    if (_rootPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _rootPath = '${dir.path}/$_folderName';
    final root = Directory(_rootPath!);
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
  }

  String _fileNameForBook(String bookUrl) {
    final hash = md5.convert(utf8.encode(bookUrl)).toString();
    return '$hash.json';
  }

  Future<List<ShelfTocEntry>> loadSnapshot(String bookUrl) async {
    try {
      await _ensureRoot();
      final file = File('$_rootPath/${_fileNameForBook(bookUrl)}');
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ShelfTocEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ShelfTocSnapshotStore.loadSnapshot: $e');
      return [];
    }
  }

  Future<void> saveSnapshot(String bookUrl, List<ShelfTocEntry> entries) async {
    try {
      await _ensureRoot();
      final file = File('$_rootPath/${_fileNameForBook(bookUrl)}');
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await file.writeAsString(encoded, flush: true);
    } catch (e) {
      debugPrint('ShelfTocSnapshotStore.saveSnapshot: $e');
    }
  }

  Future<void> deleteSnapshot(String bookUrl) async {
    try {
      await _ensureRoot();
      final file = File('$_rootPath/${_fileNameForBook(bookUrl)}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('ShelfTocSnapshotStore.deleteSnapshot: $e');
    }
  }
}
