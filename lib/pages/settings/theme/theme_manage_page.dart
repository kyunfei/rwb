import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/app_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/share_helper.dart';
import 'cloud_sync_task_page.dart';
import 'theme_edit_dialog.dart';
import 'theme_package_config.dart';

// 主题管理页面 - 完全参考 legado-main 的 ThemeManageActivity
class ThemeManagePage extends StatefulWidget {
  const ThemeManagePage({super.key});
  @override
  State<ThemeManagePage> createState() => _ThemeManagePageState();
}

class _ThemeManagePageState extends State<ThemeManagePage> {
  bool _isNightTheme = false;
  final List<ThemeConfig> _themes = [];
  String? _activeThemeId;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNightTheme = prefs.getBool('themeIsNight') ?? false;
      _activeThemeId = prefs.getString(_isNightTheme ? 'activeNightThemeId' : 'activeDayThemeId');
      
      // 加载内置主题（与 legado-main 一致）
      _themes.clear();
      // 日间主题
      _themes.add(ThemeConfig(
        id: 'builtin_default',
        name: '默认',
        isNight: false,
        isBuiltin: true,
        primaryColor: const Color(0xFF795548), // Brown 500
        accentColor: const Color(0xFFE53935), // Red 600
        backgroundColor: const Color(0xFFF5F5F5), // Grey 100
        navBarColor: const Color(0xFFEEEEEE), // Grey 200
      ));
      _themes.add(ThemeConfig(
        id: 'builtin_elegant_blue',
        name: '典雅蓝',
        isNight: false,
        isBuiltin: true,
        primaryColor: const Color(0xFF03A9F4), // Light Blue 500
        accentColor: const Color(0xFFAD1457), // Pink 800
        backgroundColor: const Color(0xFFF5F5F5),
        navBarColor: const Color(0xFFEEEEEE),
      ));
      // 夜间主题
      _themes.add(ThemeConfig(
        id: 'builtin_black_white',
        name: '黑白',
        isNight: true,
        isBuiltin: true,
        primaryColor: const Color(0xFF303030), // Grey 700
        accentColor: const Color(0xFFE0E0E0), // Grey 300
        backgroundColor: const Color(0xFF424242), // Grey 800
        navBarColor: const Color(0xFF424242),
      ));
      _themes.add(ThemeConfig(
        id: 'builtin_a_screen',
        name: 'A屏黑',
        isNight: true,
        isBuiltin: true,
        primaryColor: const Color(0xFF000000), // 纯黑
        accentColor: const Color(0xFFFFFFFF), // 纯白
        backgroundColor: const Color(0xFF000000),
        navBarColor: const Color(0xFF000000),
      ));
      
      // 加载自定义主题
      final customThemes = prefs.getStringList('customThemes') ?? [];
      for (final json in customThemes) {
        try {
          _themes.add(ThemeConfig.fromJson(json));
        } catch (e) {
          debugPrint('加载主题失败: $e');
        }
      }
      
      // 如果没有激活的主题，默认激活第一个对应模式的主题
      if (_activeThemeId == null || _activeThemeId!.isEmpty) {
        final defaultTheme = _filteredThemes.firstOrNull;
        if (defaultTheme != null) {
          _activeThemeId = defaultTheme.id;
        }
      }
    });
  }

  List<ThemeConfig> get _filteredThemes => _themes.where((t) => t.isNight == _isNightTheme).toList();

  Future<void> _saveThemes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('themeIsNight', _isNightTheme);
    await prefs.setString(_isNightTheme ? 'activeNightThemeId' : 'activeDayThemeId', _activeThemeId ?? '');
    
    final customThemes = _themes.where((t) => !t.isBuiltin).map((t) => t.toJson()).toList();
    await prefs.setStringList('customThemes', customThemes);
  }

  Future<void> _switchThemeMode(bool isNightTheme) async {
    final prefs = await SharedPreferences.getInstance();
    final nextActiveThemeId = prefs.getString(
      isNightTheme ? 'activeNightThemeId' : 'activeDayThemeId',
    );
    final fallbackTheme = _themes
        .where((t) => t.isNight == isNightTheme)
        .toList()
        .firstOrNull;

    setState(() {
      _isNightTheme = isNightTheme;
      _activeThemeId = (nextActiveThemeId != null && nextActiveThemeId.isNotEmpty)
          ? nextActiveThemeId
          : fallbackTheme?.id;
    });

    await prefs.setBool('themeIsNight', _isNightTheme);
    await prefs.setString(
      _isNightTheme ? 'activeNightThemeId' : 'activeDayThemeId',
      _activeThemeId ?? '',
    );
  }

  Future<void> _applyTheme(ThemeConfig theme) async {
    final provider = context.read<AppProvider>();

    // 根据主题类型切换主题模式（参考原版 legado-main 的 applyConfig 方法）
    if (theme.isNight) {
      provider.setThemeMode(ThemeMode.dark);
      await provider.setNightThemeColors(
        primaryColor: theme.primaryColor,
        accentColor: theme.accentColor,
        backgroundColor: theme.backgroundColor,
        surfaceColor: theme.backgroundColor,
        navBarColor: theme.navBarColor,
        backgroundImage: theme.mainBgImage ?? '',
        backgroundBlur: theme.bgImageBlur,
        bookInfoBackgroundImage: theme.bookInfoBgImage ?? '',
        panelBackgroundImage: theme.panelBgImage ?? '',
        panelBackgroundMode: theme.panelBgMode,
        cornerScale: theme.cornerScale,
        layoutAlpha: theme.layoutAlpha,
        panelBorderColor: theme.panelBorderColor ?? Colors.transparent,
        panelBorderAlpha: theme.panelBorderAlpha,
        searchFollow: theme.searchFollow,
        replyFollow: theme.replyFollow,
        fontScale: theme.fontScale,
        uiFontPath: theme.uiFont ?? '',
        titleFontPath: theme.titleFont ?? '',
      );
    } else {
      provider.setThemeMode(ThemeMode.light);
      await provider.setDayThemeColors(
        primaryColor: theme.primaryColor,
        accentColor: theme.accentColor,
        backgroundColor: theme.backgroundColor,
        surfaceColor: theme.backgroundColor,
        navBarColor: theme.navBarColor,
        backgroundImage: theme.mainBgImage ?? '',
        backgroundBlur: theme.bgImageBlur,
        bookInfoBackgroundImage: theme.bookInfoBgImage ?? '',
        panelBackgroundImage: theme.panelBgImage ?? '',
        panelBackgroundMode: theme.panelBgMode,
        cornerScale: theme.cornerScale,
        layoutAlpha: theme.layoutAlpha,
        panelBorderColor: theme.panelBorderColor ?? Colors.transparent,
        panelBorderAlpha: theme.panelBorderAlpha,
        searchFollow: theme.searchFollow,
        replyFollow: theme.replyFollow,
        fontScale: theme.fontScale,
        uiFontPath: theme.uiFont ?? '',
        titleFontPath: theme.titleFont ?? '',
      );
    }
    setState(() => _activeThemeId = theme.id);
    await _saveThemes();
    await _recordCloudSyncTask('主题已应用', theme);

    // 显示提示信息
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已应用主题: ${theme.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('主题管理'),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (value) {
              switch (value) {
                case 'export_all':
                  _exportAllThemes();
                  break;
                case 'import':
                  _importThemes();
                  break;
                case 'cloud_sync_tasks':
                  Navigator.push(
                    context,
                    AppPageRoute(builder: (_) => const CloudSyncTaskPage()),
                  );
                  break;
                case 'reset':
                  _resetToDefault();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export_all',
                child: Text('导出全部主题'),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Text('导入主题包'),
              ),
              const PopupMenuItem(
                value: 'cloud_sync_tasks',
                child: Text('云端同步任务'),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Text('恢复默认主题'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // TabBar - 完全参考 legado-main 的 tabBar 样式
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            height: 42,
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (_isNightTheme) {
                        await _switchThemeMode(false);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: !_isNightTheme 
                            ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06))
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '日间主题',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: !_isNightTheme 
                                ? colorScheme.secondary // 使用强调色
                                : (isDark ? const Color(0xDEFFFFFF) : const Color(0xDE000000)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (!_isNightTheme) {
                        await _switchThemeMode(true);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isNightTheme 
                            ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06))
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '夜间主题',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isNightTheme 
                                ? colorScheme.secondary // 使用强调色
                                : (isDark ? const Color(0xDEFFFFFF) : const Color(0xDE000000)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // tv_summary - 摘要文本
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            constraints: const BoxConstraints(minHeight: 18),
            child: Text(
              _filteredThemes.isEmpty 
                ? '暂无${_isNightTheme ? "夜间" : "日间"}主题，点击下方添加'
                : '点击应用按钮应用主题，点击编辑按钮编辑主题',
              style: TextStyle(
                fontSize: 13,
                color: isDark 
                    ? const Color(0xB3FFFFFF)  // 夜间：70%白
                    : const Color(0x8A000000), // 日间：54%黑
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // RecyclerView - 主题列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filteredThemes.length,
              itemBuilder: (context, index) {
                final theme = _filteredThemes[index];
                final isActive = theme.id == _activeThemeId;
                return _buildThemeCard(theme, isActive);
              },
            ),
          ),
          
          // btn_add - 添加按钮 (半透明背景 + 边框)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _addTheme,
              child: const Center(
                child: Text(
                  '添加主题',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 主题卡片 - 完全参考 legado-main 的 item_theme_package.xml
  Widget _buildThemeCard(ThemeConfig theme, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = '${theme.updatedAt.year}-${theme.updatedAt.month.toString().padLeft(2, '0')}-${theme.updatedAt.day.toString().padLeft(2, '0')}';
    
    // 参考 legado-main: 日间 primaryText=#de000000(87%黑), 夜间 primaryText=#ffffffff(100%白)
    final primaryTextColor = isDark 
        ? const Color(0xDEFFFFFF)  // 夜间：87%白
        : const Color(0xDE000000); // 日间：87%黑
    final secondaryTextColor = isDark 
        ? const Color(0xB3FFFFFF)  // 夜间：70%白
        : const Color(0x8A000000); // 日间：54%黑
    
    // 原版使用 bg_book_info_intro_panel 背景
    // 卡片背景是透明的，没有边框
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minHeight: 122),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // card_preview - 预览卡片 (74dp x 102dp)
          // 显示背景图片预览，参考原版 bindPreview 方法
          Container(
            width: 74,
            height: 102,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), // ui_panel_radius
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.hardEdge,
              child: Container(
                color: theme.backgroundColor,
                child: _buildThemePreview(theme),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // lay_info - 信息区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称 + 来源标签
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (theme.isBuiltin)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        constraints: const BoxConstraints(maxWidth: 118),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '内置',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                
                // tv_info - 信息文本
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${isActive ? "当前应用 · " : ""}${_isNightTheme ? "夜间" : "日间"} · $dateFormat',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 底部按钮
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // btn_apply - 应用按钮
                      _buildActionButton(
                        isActive ? '已应用' : '应用',
                        () => _applyTheme(theme),
                        textColor: isActive ? Colors.red : null,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // btn_edit - 编辑按钮
                      _buildActionButton('编辑', () => _editTheme(theme), 
                        isDark: isDark, 
                        primaryTextColor: primaryTextColor,
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // btn_more - 更多按钮
                      if (!theme.isBuiltin)
                        _buildActionButton('更多', () => _showMoreOptions(theme),
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    VoidCallback onTap, {
    Color? textColor,
    bool isDark = false,
    Color? primaryTextColor,
  }) {
    // 参考 legado-main: 日间 background_menu=#F1F2F6, 夜间 background_menu=#252528
    final bgColor = isDark 
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final defaultTextColor = primaryTextColor ?? 
        (isDark ? const Color(0xDEFFFFFF) : const Color(0xDE000000));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: textColor ?? defaultTextColor,
              fontWeight: textColor == null ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建主题预览 - 参考原版 bindPreview 方法
  /// 如果有背景图片则显示背景图片，否则显示默认预览效果
  Widget _buildThemePreview(ThemeConfig theme) {
    final backgroundPath = theme.mainBgImage;
    
    // 如果有背景图片，显示背景图片
    if (backgroundPath != null && backgroundPath.isNotEmpty) {
      Widget imageWidget;
      
      if (backgroundPath.startsWith('http://') || backgroundPath.startsWith('https://')) {
        // 网络图片
        imageWidget = Image.network(
          backgroundPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 加载失败时显示默认预览
            return _buildDefaultPreview(theme);
          },
        );
      } else {
        // 本地文件
        imageWidget = Image.file(
          File(backgroundPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 加载失败时显示默认预览
            return _buildDefaultPreview(theme);
          },
        );
      }
      
      return imageWidget;
    }
    
    // 没有背景图片时，显示默认预览效果
    return _buildDefaultPreview(theme);
  }
  
  /// 构建默认预览效果 - 模拟主题样式
  Widget _buildDefaultPreview(ThemeConfig theme) {
    return Stack(
      children: [
        // 模拟主题预览
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 44,
          child: Container(
            width: 56,
            height: 8,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 56,
          child: Container(
            width: 40,
            height: 8,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  void _addTheme() {
    _editTheme(null);
  }

  void _editTheme(ThemeConfig? existing) {
    final isBuiltinCopy = existing?.isBuiltin == true;
    final isEdit = existing != null && !isBuiltinCopy;
    final theme = existing?.copy() ?? ThemeConfig(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: '新主题',
      isNight: _isNightTheme,
      isBuiltin: false,
      primaryColor: _isNightTheme ? const Color(0xFF303030) : const Color(0xFF795548),
      accentColor: _isNightTheme ? const Color(0xFFE0E0E0) : const Color(0xFFE53935),
      backgroundColor: _isNightTheme ? const Color(0xFF424242) : const Color(0xFFF5F5F5),
      navBarColor: _isNightTheme ? const Color(0xFF424242) : const Color(0xFFEEEEEE),
    );
    if (isBuiltinCopy) {
      theme
        ..id = 'custom_${DateTime.now().millisecondsSinceEpoch}'
        ..name = '${theme.name} 副本'
        ..isBuiltin = false
        ..updatedAt = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (ctx) => ThemeEditDialog(
        theme: theme,
        isEdit: isEdit,
        onSave: (updatedTheme) async {
          if (isEdit) {
            final index = _themes.indexWhere((item) => item.id == updatedTheme.id);
            if (index >= 0) {
              setState(() => _themes[index] = updatedTheme);
            }
          } else {
            setState(() => _themes.add(updatedTheme));
          }
          await _saveThemes();
          await _recordCloudSyncTask('主题已保存', updatedTheme);
          if (isEdit && updatedTheme.id == _activeThemeId) {
            await _applyTheme(updatedTheme);
          }
        },
      ),
    );
  }

  void _showMoreOptions(ThemeConfig theme) {
    // 使用中间显示的选择对话框，匹配原版 legado-main 的 selector 样式
    // 原版使用 AlertDialog.setItems() 显示简单列表
    // 根据原版 ThemeManageActivity.showActions() 的逻辑
    final items = <Widget>[];
    
    // 应用 - 始终显示
    items.add(_buildDialogItem('应用', () {
      Navigator.pop(context);
      _applyTheme(theme);
    }));
    
    // 非内置主题可以编辑和导出
    if (!theme.isBuiltin) {
      items.add(_buildDialogItem('编辑', () {
        Navigator.pop(context);
        _editTheme(theme);
      }));
      items.add(_buildDialogItem('复制主题', () {
        Navigator.pop(context);
        _copyTheme(theme);
      }));
      items.add(_buildDialogItem('导出主题包', () {
        Navigator.pop(context);
        _exportTheme(theme);
      }));
    }
    
    // 非内置主题且非当前应用的主题可以删除
    if (!theme.isBuiltin && theme.id != _activeThemeId) {
      items.add(_buildDialogItem('删除主题', () {
        Navigator.pop(context);
        _deleteTheme(theme);
      }, isDestructive: true));
    }
    
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(theme.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: items,
        ),
      ),
    );
  }

  // 对话框列表项构建器
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

  void _exportTheme(ThemeConfig theme) {
    final json = theme.toJson();
    ShareHelper.shareText(context, json, subject: '主题分享');
  }

  Future<void> _copyTheme(ThemeConfig theme) async {
    final json = theme.toJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<void> _recordCloudSyncTask(String action, ThemeConfig theme) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList('cloudSyncTasks') ?? [];
    tasks.insert(
      0,
      jsonEncode({
        'action': action,
        'themeId': theme.id,
        'themeName': theme.name,
        'time': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    if (tasks.length > 20) {
      tasks.removeRange(20, tasks.length);
    }
    await prefs.setStringList('cloudSyncTasks', tasks);
  }

  void _exportAllThemes() {
    final customThemes = _themes.where((t) => !t.isBuiltin).toList();
    if (customThemes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的自定义主题')),
      );
      return;
    }
    
    final jsonList = customThemes.map((t) => t.toJson()).join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已导出 ${customThemes.length} 个主题'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('导出数据'),
                content: SingleChildScrollView(
                  child: SelectableText(jsonList),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _importThemes() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入主题包'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '粘贴一个或多个主题配置，每行一个',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final lines = controller.text
                  .split(RegExp(r'[\r\n]+'))
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty);
              final imported = <ThemeConfig>[];
              var failed = 0;
              for (final line in lines) {
                try {
                  final theme = ThemeConfig.fromJson(line)
                    ..id = 'custom_${DateTime.now().microsecondsSinceEpoch}_${imported.length}'
                    ..isBuiltin = false
                    ..updatedAt = DateTime.now();
                  imported.add(theme);
                } catch (_) {
                  failed++;
                }
              }
              if (imported.isNotEmpty) {
                setState(() => _themes.addAll(imported));
                await _saveThemes();
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    imported.isEmpty
                        ? '没有可导入的有效主题'
                        : '已导入 ${imported.length} 个主题${failed > 0 ? '，$failed 个失败' : ''}',
                  ),
                ),
              );
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认主题'),
        content: const Text('确定要恢复默认主题吗？这将删除所有自定义主题。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _themes.removeWhere((t) => !t.isBuiltin);
              });
              await _saveThemes();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已恢复默认主题')),
              );
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteTheme(ThemeConfig theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除主题 "${theme.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              setState(() => _themes.remove(theme));
              await _saveThemes();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
