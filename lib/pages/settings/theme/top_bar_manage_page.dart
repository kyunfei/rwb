import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'top_bar_config.dart';
import 'top_bar_edit_dialog.dart';

// 顶栏管理页面 - 参考 legado-main 的 TopBarManageActivity
class TopBarManagePage extends StatefulWidget {
  const TopBarManagePage({super.key});
  @override
  State<TopBarManagePage> createState() => _TopBarManagePageState();
}

class _TopBarManagePageState extends State<TopBarManagePage> {
  bool _isNightMode = false;
  final List<TopBarConfig> _configs = [];
  String? _activeConfigId;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNightMode = prefs.getBool('topBarIsNight') ?? false;
      _activeConfigId = prefs.getString(_isNightMode ? 'activeNightTopBarId' : 'activeDayTopBarId');

      _configs.clear();
      // 日间默认顶栏包
      _configs.add(TopBarConfig(
        id: 'builtin_default_day',
        name: '默认',
        isNight: false,
        isBuiltin: true,
        style: 'default',
        cornerScale: 1.0,
        tagBarAlpha: 100,
        tagSelectedAlpha: 100,
        wallpaperAlpha: 100,
      ));
      // 夜间默认顶栏包
      _configs.add(TopBarConfig(
        id: 'builtin_default_night',
        name: '默认',
        isNight: true,
        isBuiltin: true,
        style: 'default',
        cornerScale: 1.0,
        tagBarAlpha: 100,
        tagSelectedAlpha: 100,
        wallpaperAlpha: 100,
      ));

      // 加载自定义顶栏包
      final customConfigs = prefs.getStringList('customTopBarConfigs') ?? [];
      for (final json in customConfigs) {
        try {
          _configs.add(TopBarConfig.fromJson(json));
        } catch (e) {
          debugPrint('加载顶栏包失败: $e');
        }
      }

      if (_activeConfigId == null || _activeConfigId!.isEmpty) {
        final defaultConfig = _filteredConfigs.firstOrNull;
        if (defaultConfig != null) {
          _activeConfigId = defaultConfig.id;
        }
      }
    });
  }

  List<TopBarConfig> get _filteredConfigs => _configs.where((c) => c.isNight == _isNightMode).toList();

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('topBarIsNight', _isNightMode);
    await prefs.setString(_isNightMode ? 'activeNightTopBarId' : 'activeDayTopBarId', _activeConfigId ?? '');

    final customConfigs = _configs.where((c) => !c.isBuiltin).map((c) => c.toJson()).toList();
    await prefs.setStringList('customTopBarConfigs', customConfigs);
  }

  Future<void> _applyConfig(TopBarConfig config) async {
    setState(() => _activeConfigId = config.id);
    await _saveConfigs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已应用顶栏包: ${config.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('顶栏管理'),
      ),
      body: Column(
        children: [
          // TabBar - 日间/夜间切换
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (_isNightMode) {
                        setState(() => _isNightMode = false);
                        _activeConfigId = _filteredConfigs.firstOrNull?.id;
                        await _saveConfigs();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: !_isNightMode ? colorScheme.surface : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '日间',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: !_isNightMode ? colorScheme.secondary : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (!_isNightMode) {
                        setState(() => _isNightMode = true);
                        _activeConfigId = _filteredConfigs.firstOrNull?.id;
                        await _saveConfigs();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isNightMode ? colorScheme.surface : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '夜间',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isNightMode ? colorScheme.secondary : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 摘要文本
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            constraints: const BoxConstraints(minHeight: 18),
            child: Text(
              _filteredConfigs.isEmpty
                ? '暂无${_isNightMode ? "夜间" : "日间"}顶栏包，点击下方添加'
                : '管理主页面顶栏的${_isNightMode ? "夜间" : "日间"}样式',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 顶栏包列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filteredConfigs.length,
              itemBuilder: (context, index) {
                final config = _filteredConfigs[index];
                final isActive = config.id == _activeConfigId;
                return _buildTopBarCard(config, isActive);
              },
            ),
          ),

          // 添加按钮
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
              onTap: _showAddOptions,
              child: Center(
                child: Text(
                  '添加顶栏包',
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

  void _showAddOptions() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加顶栏包'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogItem('手动配置', () {
              Navigator.pop(ctx);
              _addConfig();
            }),
            _buildDialogItem('导入顶栏包', () async {
              Navigator.pop(ctx);
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['zip'],
                allowCompression: false,
              );
              if (result != null && result.files.isNotEmpty) {
                final path = result.files.first.path;
                if (path != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('选择文件: $path')),
                  );
                }
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogItem(String text, VoidCallback onTap, {bool isDestructive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? const Color(0xDEFFFFFF)
        : const Color(0xDE000000);
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

  // 顶栏包卡片
  Widget _buildTopBarCard(TopBarConfig config, bool isActive) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = '${config.updatedAt.year}-${config.updatedAt.month.toString().padLeft(2, '0')}-${config.updatedAt.day.toString().padLeft(2, '0')}';

    // 构建信息文本
    String infoText = _getStyleText(config.style);
    if (config.style == 'regular') {
      infoText += ' · 圆角 ${config.cornerScale.toStringAsFixed(1)}';
      if (config.wallpaperPath != null && config.wallpaperPath!.isNotEmpty) {
        infoText += ' · 壁纸';
      }
    }
    infoText += ' · 标签透明度 ${config.tagBarAlpha}%';
    infoText += ' · $dateFormat';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称 + 内置标签
          Row(
            children: [
              Expanded(
                child: Text(
                  config.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (config.isBuiltin)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '内置',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),

          // 信息文本
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${isActive ? "当前应用 · " : ""}$infoText',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 8),

          // 底部按钮
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  isActive ? '已应用' : '应用',
                  () => _applyConfig(config),
                  isPrimary: !isActive,
                ),
                const SizedBox(width: 8),
                if (!config.isBuiltin)
                  _buildActionButton('编辑', () => _editConfig(config)),
                if (!config.isBuiltin) const SizedBox(width: 8),
                _buildActionButton('更多', () => _showMoreOptions(config)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap, {bool isPrimary = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isPrimary ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isPrimary ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _getStyleText(String style) {
    switch (style) {
      case 'regular': return '常规顶栏';
      default: return '默认顶栏';
    }
  }

  void _addConfig() {
    _editConfig(null);
  }

  void _editConfig(TopBarConfig? existing) {
    final isEdit = existing != null;
    final config = existing ?? TopBarConfig(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _getNextConfigName(),
      isNight: _isNightMode,
      isBuiltin: false,
      style: 'default',
      cornerScale: 1.0,
      tagBarAlpha: 100,
      tagSelectedAlpha: 100,
      wallpaperAlpha: 100,
    );

    showDialog(
      context: context,
      builder: (ctx) => TopBarEditDialog(
        config: config,
        isEdit: isEdit,
        onSave: (updatedConfig) async {
          if (isEdit) {
            setState(() {});
          } else {
            setState(() => _configs.add(updatedConfig));
          }
          await _saveConfigs();
        },
      ),
    );
  }

  String _getNextConfigName() {
    const base = '自定义顶栏';
    final usedNames = _configs.map((c) => c.name).toSet();
    if (!usedNames.contains(base)) return base;
    for (int index = 2; index <= 999; index++) {
      final name = '$base $index';
      if (!usedNames.contains(name)) return name;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  void _showMoreOptions(TopBarConfig config) {
    final items = <Widget>[];

    items.add(_buildDialogItem('应用', () {
      Navigator.pop(context);
      _applyConfig(config);
    }));

    if (!config.isBuiltin) {
      items.add(_buildDialogItem('编辑', () {
        Navigator.pop(context);
        _editConfig(config);
      }));
      items.add(_buildDialogItem('导出顶栏包', () {
        Navigator.pop(context);
        _exportConfig(config);
      }));
    }

    if (!config.isBuiltin && config.id != _activeConfigId) {
      items.add(_buildDialogItem('删除顶栏包', () {
        Navigator.pop(context);
        _deleteConfig(config);
      }, isDestructive: true));
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(config.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: items,
        ),
      ),
    );
  }

  void _exportConfig(TopBarConfig config) {
    final json = config.toJson();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('顶栏包配置已生成\n$json'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _deleteConfig(TopBarConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除顶栏包 "${config.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              setState(() => _configs.remove(config));
              await _saveConfigs();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

