import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/cover_config_service.dart';

/// 图集详情页 - 完全参考原版 CoverCollectionDetailActivity
class CoverCollectionDetailPage extends StatefulWidget {
  final CoverCollection collection;

  const CoverCollectionDetailPage({super.key, required this.collection});

  @override
  State<CoverCollectionDetailPage> createState() => _CoverCollectionDetailPageState();
}

class _CoverCollectionDetailPageState extends State<CoverCollectionDetailPage> {
  late CoverCollection _collection;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    // 使用addPostFrameCallback延迟加载，让页面先完成渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadCollection();
    });
  }

  Future<void> _reloadCollection() async {
    final collections = await CoverCollectionManager.instance.getCollections(_collection.isNight);
    final updated = collections.where((c) => c.id == _collection.id).firstOrNull;
    if (updated != null && mounted) {
      setState(() => _collection = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: '导入图片',
            onPressed: _importImages,
          ),
        ],
      ),
      body: _collection.images.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '暂无图片，点击右上角按钮导入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0, // 150dp高度，保持正方形
              ),
              itemCount: _collection.images.length,
              itemBuilder: (ctx, index) => _buildImageItem(index),
            ),
    );
  }

  // 图片项 - 完全参考原版 item_cover_collection_image.xml
  // FrameLayout: 150dp高度，5dp margin，4dp padding
  Widget _buildImageItem(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = _collection.images[index];
    
    return GestureDetector(
      onLongPress: () => _removeImage(index),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.hardEdge,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _importImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.paths.isNotEmpty) {
        final paths = result.paths.whereType<String>().toList();
        await CoverCollectionManager.instance.importImages(
          _collection.id, paths, _collection.isNight,
        );
        await _reloadCollection();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入${paths.length}张图片')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入图片失败: $e')),
        );
      }
    }
  }

  void _removeImage(int index) async {
    final colorScheme = Theme.of(context).colorScheme;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除图片'),
        content: const Text('确定要删除这张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CoverCollectionManager.instance.removeImage(
          _collection.id, _collection.images[index], _collection.isNight,
        );
        await _reloadCollection();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}
