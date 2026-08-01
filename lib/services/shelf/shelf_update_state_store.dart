import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/shelf/shelf_book_update_state.dart';

class ShelfUpdateStateStore {
  ShelfUpdateStateStore._();
  static final ShelfUpdateStateStore instance = ShelfUpdateStateStore._();

  static const _fileName = 'shelf_update_states.json';
  String? _filePath;
  Map<String, ShelfBookUpdateState> _cache = {};

  Future<void> _ensureLoaded() async {
    if (_filePath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/$_fileName';
    final file = File(_filePath!);
    if (!await file.exists()) {
      _cache = {};
      return;
    }
    try {
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = map.map(
        (key, value) => MapEntry(
          key,
          ShelfBookUpdateState.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      debugPrint('ShelfUpdateStateStore load error: $e');
      _cache = {};
    }
  }

  Future<void> _persist() async {
    await _ensureLoaded();
    final file = File(_filePath!);
    final encoded = jsonEncode(
      _cache.map((k, v) => MapEntry(k, v.toJson())),
    );
    await file.writeAsString(encoded, flush: true);
  }

  Future<ShelfBookUpdateState> stateFor(String bookUrl) async {
    await _ensureLoaded();
    return _cache[bookUrl] ?? const ShelfBookUpdateState();
  }

  ShelfBookUpdateState stateForSync(String bookUrl) {
    return _cache[bookUrl] ?? const ShelfBookUpdateState();
  }

  Future<void> put(String bookUrl, ShelfBookUpdateState state) async {
    await _ensureLoaded();
    _cache[bookUrl] = state;
    await _persist();
  }

  Future<void> remove(String bookUrl) async {
    await _ensureLoaded();
    _cache.remove(bookUrl);
    await _persist();
  }

  Future<Map<String, ShelfBookUpdateState>> allStates() async {
    await _ensureLoaded();
    return Map.unmodifiable(_cache);
  }

  Future<void> loadAllIntoMemory() async {
    await _ensureLoaded();
  }
}
