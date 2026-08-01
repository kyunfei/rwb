import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/cover_config_service.dart';
import 'cover_collection_detail_page.dart';

/// 封面图集管理页 - 完全参考原版 CoverCollectionManageActivity
class CoverCollectionManagePage extends StatefulWidget {
  const CoverCollectionManagePage({super.key});

  @override
  State<CoverCollectionManagePage> createState() => _CoverCollectionManagePageState();
}

class _CoverCollectionManagePageState extends State<CoverCollectionManagePage> {
  bool _isNight = false;
  List<CoverCollection> _dayCollections = [];
  List<CoverCollection> _nightCollections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 使用addPostFrameCallback延迟加载，让页面先完成渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCollections();
    });
  }

  Future<void> _loadCollections() async {
    final day = await CoverCollectionManager.instance.getCollections(false);
    final night = await CoverCollectionManager.instance.getCollections(true);
    if (mounted) {
      setState(() {
        _dayCollections = day;
        _nightCollections = night;
        _loading = false;
      });
    }
  }

  List<CoverCollection> get _currentCollections =>
      _isNight ? _nightCollections : _dayCollections;

  Future<void> _switchTab(bool isNight) async {
    if (_isNight == isNight) return;
    setState(() => _isNight = isNight);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('封面图集'),
      ),
      body: Column(
        children: [
          // TabBar - 完全参考原版 activity_cover_collection_manage.xml 的 tabBar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchTab(false),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: !_isNight ? colorScheme.surface.withValues(alpha: 0.2) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '日间',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: !_isNight ? colorScheme.secondary : colorScheme.onSurface, // 使用强调色
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchTab(true),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isNight ? colorScheme.surface.withValues(alpha: 0.2) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '夜间',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isNight ? colorScheme.secondary : colorScheme.onSurface, // 使用强调色
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // RecyclerView - 图集列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(),
          ),
          
          // btn_add - 添加按钮 (参考原版 bg_book_info_action_secondary)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.87),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _showAddActions,
              child: Center(
                child: Text(
                  '添加图集',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddActions() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加图集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogItem('创建图集', () {
              Navigator.pop(ctx);
              _createCollection();
            }),
            _buildDialogItem('导入ZIP', () {
              Navigator.pop(ctx);
              _importZip();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogItem(String text, VoidCallback onTap, {bool isDestructive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark 
        ? const Color(0xDEFFFFFF)  // 夜间：87%白
        : const Color(0xDE000000); // 日间：87%黑
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: isDestructive ? Theme.of(context).colorScheme.error : primaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final collections = _currentCollections;
    final colorScheme = Theme.of(context).colorScheme;
    
    if (collections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '暂无${_isNight ? "夜间" : "日间"}图集，点击下方添加',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: collections.length,
      itemBuilder: (ctx, index) => _buildCollectionItem(collections[index]),
    );
  }

  // 图集卡片 - 完全参考原版 item_cover_collection.xml
  Widget _buildCollectionItem(CoverCollection collection) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(collection),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // iv_preview - 预览图 (54dp x 72dp)
            Container(
              width: 54,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: collection.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      clipBehavior: Clip.hardEdge,
                      child: Image.file(
                        File(collection.images.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.image,
                      size: 24,
                      color: colorScheme.onSurfaceVariant,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // lay_info - 信息区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // tv_name - 名称 (16sp, bold)
                  Text(
                    collection.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 5),
                  
                  // tv_info - 信息 (13sp)
                  Text(
                    '${collection.images.length}张图片',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            // btn_more - 更多按钮 (34dp高度, minWidth 56dp)
            GestureDetector(
              onTap: () => _showCollectionOptions(collection),
              child: Container(
                height: 34,
                constraints: const BoxConstraints(minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '更多',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createCollection() async {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('图集名称'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: '请输入图集名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入图集名称')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await CoverCollectionManager.instance.createCollection(
                  name: name,
                  isNight: _isNight,
                );
                await _loadCollections();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('创建失败: $e')),
                );
              }
            },
            child: Text('确定', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _importZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowCompression: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null && mounted) {
          // TODO: 实现ZIP导入功能
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('选择文件: $path')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  void _showCollectionOptions(CoverCollection collection) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(collection.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogItem('重命名', () {
              Navigator.pop(ctx);
              _renameCollection(collection);
            }),
            _buildDialogItem('导出ZIP', () {
              Navigator.pop(ctx);
              _exportCollection(collection);
            }),
            _buildDialogItem('删除', () {
              Navigator.pop(ctx);
              _deleteCollection(collection);
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  void _renameCollection(CoverCollection collection) async {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(text: collection.name);
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('图集名称'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: '请输入图集名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入图集名称')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await CoverCollectionManager.instance.renameCollection(
                  collection.id, name, collection.isNight,
                );
                await _loadCollections();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('重命名失败: $e')),
                );
              }
            },
            child: Text('确定', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _exportCollection(CoverCollection collection) {
    // TODO: 实现导出ZIP功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能待实现')),
    );
  }

  void _deleteCollection(CoverCollection collection) async {
    final colorScheme = Theme.of(context).colorScheme;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除图集 "${collection.name}" 吗？'),
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
        await CoverCollectionManager.instance.deleteCollection(
          collection.id, collection.isNight,
        );
        await _loadCollections();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _navigateToDetail(CoverCollection collection) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CoverCollectionDetailPage(collection: collection),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 使用淡入淡出过渡，更流畅
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    await _loadCollections();
  }
}

