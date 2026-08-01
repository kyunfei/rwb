import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/share_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../providers/app_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/cover_config_service.dart';
import '../../widgets/android_switch.dart';
import '../../widgets/common_widgets.dart';

import 'theme/theme_package_config.dart';
import 'theme/navigation_bar_config.dart';
import 'theme/top_bar_config.dart';
import 'theme/theme_manage_page.dart';
import 'theme/cloud_sync_task_page.dart';
import 'theme/theme_edit_dialog.dart';
import 'theme/theme_slider_track_shape.dart';
class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  bool _mainTransparentStatusBar = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainTransparentStatusBar = prefs.getBool('mainTransparentStatusBar') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.themeMode == ThemeMode.dark ||
        (provider.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题设置'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? '切换到日间模式' : '切换到夜间模式',
            onPressed: () {
              if (isDark) {
                provider.setThemeMode(ThemeMode.light);
              } else {
                provider.setThemeMode(ThemeMode.dark);
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // 通用设置
          _buildCategoryTitle('通用设置'),
          _buildSection([
            _buildSwitchItem(
              title: '主界面沉浸状态栏',
              subtitle: '主界面状态栏透明，内容延伸到状态栏下方',
              value: _mainTransparentStatusBar,
              onChanged: (value) async {
                setState(() => _mainTransparentStatusBar = value);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('mainTransparentStatusBar', value);
              },
            ),
          ]),

          // 界面管理
          _buildCategoryTitle('界面管理'),
          _buildSection([
            _buildListItem(
              title: '主题管理',
              subtitle: '管理日间/夜间主题颜色和背景',
              onTap: () => Navigator.push(context, AppPageRoute(builder: (_) => const ThemeManagePage())),
            ),
            _buildListItem(
              title: '底栏管理',
              subtitle: '管理日间/夜间底栏样式和布局',
              onTap: () => Navigator.push(context, AppPageRoute(builder: (_) => const NavigationBarManagePage())),
            ),
            _buildListItem(
              title: '顶栏管理',
              subtitle: '管理日间/夜间顶栏样式和布局',
              onTap: () => Navigator.push(context, AppPageRoute(builder: (_) => const TopBarManagePage())),
            ),
            _buildListItem(
              title: '书籍信息管理',
              subtitle: '自定义书籍详情页样式',
              onTap: () => Navigator.push(context, AppPageRoute(builder: (_) => const BookInfoManagePage())),
            ),
            _buildListItem(
              title: '气泡管理',
              subtitle: '自定义气泡样式',
              onTap: () => Navigator.push(context, AppPageRoute(builder: (_) => const BubbleManagePage())),
            ),
          ]),

          // 其他设置
          _buildCategoryTitle('其他设置'),
          _buildSection([
            _buildListItem(
              title: '封面设置',
              subtitle: '通用封面规则及默认封面样式',
              onTap: () => Navigator.push(context, AppPageRoute(builder: (_) => const CoverConfigPage())),
            ),
          ]),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCategoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
    );
  }

  Widget _buildSection(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListItem({required String title, String? subtitle, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 参考 legado-main: 日间 primaryText=#de000000(87%黑), 夜间 primaryText=#ffffffff(100%白)
    final primaryTextColor = isDark 
        ? const Color(0xDEFFFFFF)  // 夜间：87%白
        : const Color(0xDE000000); // 日间：87%黑
    final secondaryTextColor = isDark 
        ? const Color(0xB3FFFFFF)  // 夜间：70%白
        : const Color(0x8A000000); // 日间：54%黑
    return ListTile(
      title: Text(title, style: TextStyle(color: primaryTextColor)),
      subtitle: subtitle != null 
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: secondaryTextColor)) 
          : null,
      trailing: Icon(Icons.chevron_right, color: secondaryTextColor),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 使用强调色（secondary）而不是主色（primary），参考原版 SwitchPreference
    final accentColor = Theme.of(context).colorScheme.secondary;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF212121),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : const Color(0xFF757575),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AndroidSwitch(
              value: value,
              onChanged: onChanged,
              accentColor: accentColor,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}





/// 底栏配置类 - 参考 legado-main 的 NavigationBarIconConfig.Config

// 底栏管理页面 - 参考 legado-main 的 NavigationBarManageActivity
class NavigationBarManagePage extends StatefulWidget {
  const NavigationBarManagePage({super.key});
  @override
  State<NavigationBarManagePage> createState() => _NavigationBarManagePageState();
}

class _NavigationBarManagePageState extends State<NavigationBarManagePage> {
  bool _isNightMode = false;
  final List<NavigationBarConfig> _configs = [];
  String? _activeConfigId;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNightMode = prefs.getBool('navBarIsNight') ?? false;
      _activeConfigId = prefs.getString(_isNightMode ? 'activeNightNavBarId' : 'activeDayNavBarId');
      
      // 加载内置底栏包
      _configs.clear();
      // 日间默认底栏包
      _configs.add(NavigationBarConfig(
        id: 'builtin_default_day',
        name: '默认',
        isNight: false,
        isBuiltin: true,
        layoutMode: 'floating',
        effectMode: 'glass',
        opacity: 72,
      ));
      // 夜间默认底栏包
      _configs.add(NavigationBarConfig(
        id: 'builtin_default_night',
        name: '默认',
        isNight: true,
        isBuiltin: true,
        layoutMode: 'floating',
        effectMode: 'glass',
        opacity: 72,
      ));
      
      // 加载自定义底栏包
      final customConfigs = prefs.getStringList('customNavBarConfigs') ?? [];
      for (final json in customConfigs) {
        try {
          _configs.add(NavigationBarConfig.fromJson(json));
        } catch (e) {
          debugPrint('加载底栏包失败: $e');
        }
      }
      
      // 如果没有激活的底栏包，默认激活第一个对应模式的底栏包
      if (_activeConfigId == null || _activeConfigId!.isEmpty) {
        final defaultConfig = _filteredConfigs.firstOrNull;
        if (defaultConfig != null) {
          _activeConfigId = defaultConfig.id;
        }
      }
    });
  }

  List<NavigationBarConfig> get _filteredConfigs => _configs.where((c) => c.isNight == _isNightMode).toList();

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('navBarIsNight', _isNightMode);
    await prefs.setString(_isNightMode ? 'activeNightNavBarId' : 'activeDayNavBarId', _activeConfigId ?? '');
    
    final customConfigs = _configs.where((c) => !c.isBuiltin).map((c) => c.toJson()).toList();
    await prefs.setStringList('customNavBarConfigs', customConfigs);
  }

  Future<void> _applyConfig(NavigationBarConfig config) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _activeConfigId = config.id);
    await _saveConfigs();
    if (!mounted) return;

    // 应用底栏配置到 AppProvider
    await appProvider.setNavBarConfig(
      layoutMode: config.layoutMode,
      effectMode: config.effectMode,
      opacity: config.opacity,
      borderColor: config.borderColor ?? 0,
      borderAlpha: config.borderAlpha,
      wallpaperPath: config.wallpaperPath ?? '',
      sidebarBackgroundPath: config.sidebarBackgroundPath ?? '',
      sidebarGravity: config.sidebarGravity,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已应用底栏包: ${config.name}'),
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
        title: const Text('底栏管理'),
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
                            color: !_isNightMode ? colorScheme.secondary : colorScheme.onSurface, // 使用强调色
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
                            color: _isNightMode ? colorScheme.secondary : colorScheme.onSurface, // 使用强调色
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
                ? '暂无${_isNightMode ? "夜间" : "日间"}底栏包，点击下方添加'
                : '点击应用按钮应用底栏包，点击编辑按钮编辑底栏包',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 底栏包列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filteredConfigs.length,
              itemBuilder: (context, index) {
                final config = _filteredConfigs[index];
                final isActive = config.id == _activeConfigId;
                return _buildNavBarCard(config, isActive);
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
                  '添加底栏包',
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
        title: const Text('添加底栏包'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogItem('手动配置', () {
              Navigator.pop(ctx);
              _addConfig();
            }),
            _buildDialogItem('导入底栏包', () async {
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

  // 底栏包卡片
  Widget _buildNavBarCard(NavigationBarConfig config, bool isActive) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = '${config.updatedAt.year}-${config.updatedAt.month.toString().padLeft(2, '0')}-${config.updatedAt.day.toString().padLeft(2, '0')}';
    
    // 构建信息文本
    String infoText = _getLayoutModeText(config.layoutMode);
    if (config.layoutMode == 'floating') {
      infoText += ' · ${_getEffectModeText(config.effectMode)}';
    }
    if (config.layoutMode != 'sidebar') {
      infoText += ' · 不透明度 ${config.opacity}%';
      if (config.layoutMode == 'standard' && config.wallpaperPath != null && config.wallpaperPath!.isNotEmpty) {
        infoText += ' · 底栏壁纸';
      }
    }
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

  String _getLayoutModeText(String mode) {
    switch (mode) {
      case 'floating': return '悬浮';
      case 'standard': return '标准';
      case 'sidebar': return '侧边栏';
      default: return '悬浮';
    }
  }

  String _getEffectModeText(String mode) {
    switch (mode) {
      case 'solid': return '实心';
      case 'glass': return '玻璃';
      case 'frosted': return '磨砂';
      default: return '玻璃';
    }
  }

  void _addConfig() {
    _editConfig(null);
  }

  void _editConfig(NavigationBarConfig? existing) {
    final isEdit = existing != null;
    final wasActive = isEdit && existing.id == _activeConfigId;
    final config = existing ?? NavigationBarConfig(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _getNextConfigName(),
      isNight: _isNightMode,
      isBuiltin: false,
      layoutMode: 'floating',
      effectMode: 'glass',
      opacity: 100,
    );

    showDialog(
      context: context,
      builder: (ctx) => _NavBarEditDialog(
        config: config,
        isEdit: isEdit,
        onSave: (updatedConfig) async {
          if (isEdit) {
            setState(() {});
          } else {
            setState(() => _configs.add(updatedConfig));
          }
          await _saveConfigs();
          // 如果编辑的是当前已应用的底栏包，保存后自动重新应用
          if (wasActive) {
            await _applyConfig(updatedConfig);
          }
        },
      ),
    );
  }

  String _getNextConfigName() {
    const base = '自定义底栏';
    final usedNames = _configs.map((c) => c.name).toSet();
    if (!usedNames.contains(base)) return base;
    for (int index = 2; index <= 999; index++) {
      final name = '$base $index';
      if (!usedNames.contains(name)) return name;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }

  void _showMoreOptions(NavigationBarConfig config) {
    final items = <Widget>[];
    
    // 应用
    items.add(_buildDialogItem('应用', () {
      Navigator.pop(context);
      _applyConfig(config);
    }));
    
    // 非内置主题可以编辑和导出
    if (!config.isBuiltin) {
      items.add(_buildDialogItem('编辑', () {
        Navigator.pop(context);
        _editConfig(config);
      }));
      items.add(_buildDialogItem('导出底栏包', () {
        Navigator.pop(context);
        _exportConfig(config);
      }));
    }
    
    // 非内置主题且非当前应用的主题可以删除
    if (!config.isBuiltin && config.id != _activeConfigId) {
      items.add(_buildDialogItem('删除底栏包', () {
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

  void _exportConfig(NavigationBarConfig config) {
    final json = config.toJson();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('底栏包配置已生成\n$json'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _deleteConfig(NavigationBarConfig config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除底栏包 "${config.name}" 吗？'),
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

// 底栏包编辑对话框 - 参考 legado-main 的编辑对话框
class _NavBarEditDialog extends StatefulWidget {
  final NavigationBarConfig config;
  final bool isEdit;
  final Future<void> Function(NavigationBarConfig) onSave;

  const _NavBarEditDialog({
    required this.config,
    required this.isEdit,
    required this.onSave,
  });

  @override
  State<_NavBarEditDialog> createState() => _NavBarEditDialogState();
}

class _NavBarEditDialogState extends State<_NavBarEditDialog> {
  late NavigationBarConfig _config;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _nameController.text = _config.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth * 0.94;
    final dialogHeight = screenHeight < 1600 ? screenHeight * 0.74 : screenHeight * 0.68;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.isEdit ? '编辑底栏包' : '添加底栏包',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称输入框
                    _buildOptionRow(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: '底栏包名称',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                        style: const TextStyle(fontSize: 15),
                        onChanged: (v) => _config.name = v,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 布局模式
                    _buildSelectOption(
                      '布局模式',
                      _getLayoutModeText(_config.layoutMode),
                      () => _showLayoutModePicker(),
                    ),

                    // 材质模式 - 仅悬浮模式
                    if (_config.layoutMode == 'floating')
                      _buildSelectOption(
                        '材质模式',
                        _getEffectModeText(_config.effectMode),
                        () => _showEffectModePicker(),
                      ),

                    // 底栏壁纸 - 仅标准模式
                    if (_config.layoutMode == 'standard')
                      _buildSelectOption(
                        '底栏壁纸',
                        _config.wallpaperPath != null && _config.wallpaperPath!.isNotEmpty ? '已设置' : '选择图片',
                        () => _showWallpaperPicker(),
                      ),

                    // 不透明度 - 非侧边栏模式
                    _buildSliderOption(
                      '不透明度',
                      _config.opacity.toDouble(),
                      0,
                      100,
                      (v) => setState(() => _config.opacity = v.round()),
                      isPercentage: true,
                    ),

                    // 边框颜色 - 非侧边栏模式
                    _buildColorOption(
                      '边框颜色',
                      _config.borderColor != null ? Color(_config.borderColor!) : Colors.transparent,
                      (c) => setState(() => _config.borderColor = c.toARGB32()),
                      canDisable: true,
                    ),

                    // 边框透明度 - 非侧边栏模式
                    _buildSliderOption(
                      '边框透明度',
                      _config.borderAlpha.toDouble(),
                      0,
                      100,
                      (v) => setState(() => _config.borderAlpha = v.round()),
                      isPercentage: true,
                    ),

                    // 侧边栏背景 - 仅侧边栏模式
                    if (_config.layoutMode == 'sidebar')
                      _buildSelectOption(
                        '侧边栏背景',
                        _config.sidebarBackgroundPath != null && _config.sidebarBackgroundPath!.isNotEmpty ? '已设置' : '选择图片',
                        () => _showSidebarBackgroundPicker(),
                      ),

                    // 侧边栏位置 - 仅侧边栏模式
                    if (_config.layoutMode == 'sidebar')
                      _buildSelectOption(
                        '侧边栏位置',
                        _config.sidebarGravity == 'start' ? '左侧' : '右侧',
                        () => _showSidebarGravityPicker(),
                      ),

                    // 图标配置
                    ..._buildIconRows(),
                  ],
                ),
              ),
            ),

            // 底部按钮栏
            Container(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 96,
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  SizedBox(
                    width: 96,
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await widget.onSave(_config);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildSelectOption(String title, String value, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildOptionRow(
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              width: 132,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderOption(String title, double value, double min, double max, ValueChanged<double> onChanged, {bool isPercentage = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    String valueText = isPercentage ? '${value.round()}%' : value.toStringAsFixed(1);

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showNumberPickerDialog(title, value, min, max, onChanged, isPercentage: isPercentage),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              width: 132,
              child: Text(
                valueText,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(String title, Color color, ValueChanged<Color> onChanged, {bool canDisable = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorHex = color != Colors.transparent 
        ? '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
        : '禁用';

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showColorPicker(title, color, onChanged, canDisable: canDisable),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (color != Colors.transparent)
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
              ),
            SizedBox(
              width: 132,
              child: Text(
                colorHex,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 导航项列表 - 参考原版 NavigationBarIconConfig.items
  static const _navItems = [
    _NavItem('bookshelf', '书架', Icons.menu_book),
    _NavItem('discovery', '发现', Icons.explore),
    _NavItem('rss', '订阅', Icons.rss_feed),
    _NavItem('my', '我的', Icons.person),
    _NavItem('ai', '助手', Icons.smart_toy),
  ];

  List<Widget> _buildIconRows() {
    final colorScheme = Theme.of(context).colorScheme;
    final items = _navItems.where((item) {
      // 非侧边栏模式不显示AI助手
      if (_config.layoutMode != 'sidebar' && item.key == 'ai') {
        return false;
      }
      return true;
    }).toList();

    return items.map((item) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            // 正常状态图标按钮
            _buildIconButton(item, false),
            const SizedBox(width: 8),
            // 选中状态图标按钮
            _buildIconButton(item, true),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildIconButton(_NavItem item, bool selected) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconKey = '${item.key}_${selected ? 'selected' : 'normal'}';
    final hasCustomIcon = _config.icons.containsKey(iconKey);

    return GestureDetector(
      onTap: () => _showIconOptions(item, selected),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          hasCustomIcon ? Icons.image : item.icon,
          size: 24,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _showIconOptions(_NavItem item, bool selected) {
    final iconKey = '${item.key}_${selected ? 'selected' : 'normal'}';
    final hasCustomIcon = _config.icons.containsKey(iconKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item.title} - ${selected ? '选中' : '正常'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogItem('选择图片', () {
              Navigator.pop(ctx);
              _pickIconImage(item, selected);
            }),
            if (hasCustomIcon)
              _buildDialogItem('删除', () {
                Navigator.pop(ctx);
                setState(() {
                  _config.icons.remove(iconKey);
                });
              }, isDestructive: true),
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

  Future<void> _pickIconImage(_NavItem item, bool selected) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'ico'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final iconKey = '${item.key}_${selected ? 'selected' : 'normal'}';
        setState(() {
          _config.icons[iconKey] = path;
        });
      }
    }
  }

  String _getLayoutModeText(String mode) {
    switch (mode) {
      case 'floating': return '悬浮';
      case 'standard': return '标准';
      case 'sidebar': return '侧边栏';
      default: return '悬浮';
    }
  }

  String _getEffectModeText(String mode) {
    switch (mode) {
      case 'solid': return '实心';
      case 'glass': return '玻璃';
      case 'frosted': return '磨砂';
      default: return '玻璃';
    }
  }

  void _showLayoutModePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('布局模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('悬浮'),
              subtitle: const Text('悬浮在底部，支持玻璃效果'),
              trailing: _config.layoutMode == 'floating' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.layoutMode = 'floating');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('标准'),
              subtitle: const Text('传统底部导航栏样式'),
              trailing: _config.layoutMode == 'standard' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() {
                  _config.layoutMode = 'standard';
                  _config.effectMode = 'solid';
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('侧边栏'),
              subtitle: const Text('侧边抽屉式导航'),
              trailing: _config.layoutMode == 'sidebar' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.layoutMode = 'sidebar');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEffectModePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('材质模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('实心'),
              trailing: _config.effectMode == 'solid' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.effectMode = 'solid');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('玻璃'),
              trailing: _config.effectMode == 'glass' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.effectMode = 'glass');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('磨砂'),
              trailing: _config.effectMode == 'frosted' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.effectMode = 'frosted');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSidebarGravityPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('侧边栏位置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('左侧'),
              trailing: _config.sidebarGravity == 'start' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.sidebarGravity = 'start');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('右侧'),
              trailing: _config.sidebarGravity == 'end' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.sidebarGravity = 'end');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWallpaperPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() => _config.wallpaperPath = path);
      }
    }
  }

  void _showSidebarBackgroundPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() => _config.sidebarBackgroundPath = path);
      }
    }
  }

  void _showNumberPickerDialog(String title, double currentValue, double min, double max, ValueChanged<double> onChanged, {bool isPercentage = false}) {
    double value = currentValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: (v) => setState(() => value = v),
                ),
                Text(
                  isPercentage ? '${value.round()}%' : value.round().toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  onChanged(value);
                  Navigator.pop(ctx);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showColorPicker(String title, Color currentColor, ValueChanged<Color> onChanged, {bool canDisable = false}) {
    if (canDisable) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('禁用'),
                onTap: () {
                  Navigator.pop(ctx);
                  onChanged(Colors.transparent);
                },
              ),
              ListTile(
                title: const Text('选择颜色'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showColorPickerDialog(title, currentColor, onChanged);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _showColorPickerDialog(title, currentColor, onChanged);
    }
  }

  void _showColorPickerDialog(String title, Color currentColor, ValueChanged<Color> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;
    
    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;
    bool isEditingColorCode = false;
    
    final colorController = TextEditingController(
      text: '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    final colorFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
          
          final colorHex = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
          if (!isEditingColorCode && colorController.text != colorHex) {
            colorController.text = colorHex;
            colorController.selection = TextSelection.collapsed(offset: colorHex.length);
          }
          
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 1,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 色相滑块
                  _buildColorSlider(
                    label: '色相',
                    value: hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) {
                      colorFocusNode.unfocus();
                      setDialogState(() {
                        isEditingColorCode = false;
                        hue = v;
                      });
                    },
                    displayValue: hue.round().toString(),
                    gradientColors: [
                      const Color(0xFFFF0000),
                      const Color(0xFFFFFF00),
                      const Color(0xFF00FF00),
                      const Color(0xFF00FFFF),
                      const Color(0xFF0000FF),
                      const Color(0xFFFF00FF),
                      const Color(0xFFFF0000),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 饱和度滑块
                  _buildColorSlider(
                    label: '饱和度',
                    value: saturation,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      colorFocusNode.unfocus();
                      setDialogState(() {
                        isEditingColorCode = false;
                        saturation = v;
                      });
                    },
                    displayValue: '${(saturation * 100).round()}%',
                    gradientColors: [
                      HSVColor.fromAHSV(1.0, hue, 0, value).toColor(),
                      HSVColor.fromAHSV(1.0, hue, 1, value).toColor(),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 明度滑块
                  _buildColorSlider(
                    label: '明度',
                    value: value,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      colorFocusNode.unfocus();
                      setDialogState(() {
                        isEditingColorCode = false;
                        value = v;
                      });
                    },
                    displayValue: '${(value * 100).round()}%',
                    gradientColors: [
                      HSVColor.fromAHSV(1.0, hue, saturation, 0).toColor(),
                      HSVColor.fromAHSV(1.0, hue, saturation, 1).toColor(),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController,
                          focusNode: colorFocusNode,
                          decoration: InputDecoration(
                            hintText: '#RRGGBB',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          onTap: () {
                            isEditingColorCode = true;
                          },
                          onChanged: (text) {
                            final color = _parseColor(text);
                            if (color == null) return;
                            final hsv = HSVColor.fromColor(color);
                            setDialogState(() {
                              hue = hsv.hue;
                              saturation = hsv.saturation;
                              value = hsv.value;
                            });
                          },
                          onSubmitted: (text) {
                            final color = _parseColor(text);
                            if (color == null) return;
                            final hsv = HSVColor.fromColor(color);
                            setDialogState(() {
                              hue = hsv.hue;
                              saturation = hsv.saturation;
                              value = hsv.value;
                              isEditingColorCode = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          '取消',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          onChanged(
                            _parseColor(colorController.text) ?? selectedColor,
                          );
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          '确定',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      colorController.dispose();
      colorFocusNode.dispose();
    });
  }

  Color? _parseColor(String text) {
    var value = text.trim();
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    if (value.toLowerCase().startsWith('0x')) {
      value = value.substring(2);
    }

    if (value.length != 6 && value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(value.length == 6 ? parsed + 0xFF000000 : parsed);
  }

  Widget _buildColorSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
    required List<Color> gradientColors,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 24,
                  trackShape: const _FullWidthSliderTrackShape(),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            displayValue,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

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
      builder: (ctx) => _TopBarEditDialog(
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

// 顶栏包编辑对话框 - 参考 legado-main 的 TopBarManageActivity.buildEditView
class _TopBarEditDialog extends StatefulWidget {
  final TopBarConfig config;
  final bool isEdit;
  final Future<void> Function(TopBarConfig) onSave;

  const _TopBarEditDialog({
    required this.config,
    required this.isEdit,
    required this.onSave,
  });

  @override
  State<_TopBarEditDialog> createState() => _TopBarEditDialogState();
}

class _TopBarEditDialogState extends State<_TopBarEditDialog> {
  late TopBarConfig _config;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _nameController.text = _config.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth * 0.94;
    final dialogHeight = screenHeight < 1600 ? screenHeight * 0.74 : screenHeight * 0.68;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.isEdit ? '编辑顶栏包' : '添加顶栏包',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称输入框
                    _buildOptionRow(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: '顶栏包名称',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                        style: const TextStyle(fontSize: 15),
                        onChanged: (v) => _config.name = v,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 顶栏样式
                    _buildSelectOption(
                      '顶栏样式',
                      _getStyleText(_config.style),
                      () => _showStylePicker(),
                    ),

                    // 常规样式专属选项
                    if (_config.style == 'regular') ...[
                      _buildSliderOption(
                        '圆角倍率',
                        _config.cornerScale * 10,
                        0,
                        30,
                        (v) => setState(() => _config.cornerScale = v / 10),
                        displayValue: _config.cornerScale.toStringAsFixed(1),
                      ),
                      _buildColorOption(
                        '背景色',
                        _config.backgroundColor != null ? Color(_config.backgroundColor!) : (_config.isNight ? Colors.black : Colors.white),
                        (c) => setState(() => _config.backgroundColor = c.toARGB32()),
                      ),
                      _buildSelectOption(
                        '顶栏壁纸',
                        _config.wallpaperPath != null && _config.wallpaperPath!.isNotEmpty ? '已设置' : '选择图片',
                        () => _showWallpaperPicker(),
                      ),
                      _buildSliderOption(
                        '壁纸透明度',
                        _config.wallpaperAlpha.toDouble(),
                        0,
                        100,
                        (v) => setState(() => _config.wallpaperAlpha = v.round()),
                        isPercentage: true,
                      ),
                      _buildSelectOption(
                        '筛选栏默认状态',
                        _config.expandFiltersByDefault ? '展开' : '折叠',
                        () => _showFilterDefaultPicker(),
                      ),
                    ],

                    // 标签栏背景色
                    _buildColorOption(
                      '标签栏背景',
                      _config.tagBarColor != null ? Color(_config.tagBarColor!) : (_config.style == 'regular' ? Colors.white : colorScheme.surfaceContainerHighest),
                      (c) => setState(() => _config.tagBarColor = c.toARGB32()),
                    ),

                    // 标签栏透明度
                    _buildSliderOption(
                      '标签栏透明度',
                      _config.tagBarAlpha.toDouble(),
                      0,
                      100,
                      (v) => setState(() => _config.tagBarAlpha = v.round()),
                      isPercentage: true,
                    ),

                    // 选中标签背景色
                    _buildColorOption(
                      '选中标签背景',
                      _config.tagSelectedColor != null ? Color(_config.tagSelectedColor!) : colorScheme.surface,
                      (c) => setState(() => _config.tagSelectedColor = c.toARGB32()),
                    ),

                    // 选中标签透明度
                    _buildSliderOption(
                      '选中标签透明度',
                      _config.tagSelectedAlpha.toDouble(),
                      0,
                      100,
                      (v) => setState(() => _config.tagSelectedAlpha = v.round()),
                      isPercentage: true,
                    ),
                  ],
                ),
              ),
            ),

            // 底部按钮栏
            Container(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 96,
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  SizedBox(
                    width: 96,
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await widget.onSave(_config);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildSelectOption(String title, String value, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildOptionRow(
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              width: 132,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderOption(String title, double value, double min, double max, ValueChanged<double> onChanged, {bool isPercentage = false, String? displayValue}) {
    final colorScheme = Theme.of(context).colorScheme;
    String valueText = displayValue ?? (isPercentage ? '${value.round()}%' : value.toStringAsFixed(1));

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showNumberPickerDialog(title, value, min, max, onChanged, isPercentage: isPercentage),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(
              width: 132,
              child: Text(
                valueText,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(String title, Color color, ValueChanged<Color> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showColorPicker(title, color, onChanged),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
            ),
            SizedBox(
              width: 132,
              child: Text(
                colorHex,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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

  void _showStylePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('顶栏样式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('默认顶栏'),
              subtitle: const Text('系统默认顶栏样式'),
              trailing: _config.style == 'default' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.style = 'default');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('常规顶栏'),
              subtitle: const Text('支持圆角、壁纸、背景色等自定义'),
              trailing: _config.style == 'regular' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() {
                  _config.style = 'regular';
                  _config.backgroundColor ??= (_config.isNight ? Colors.black : Colors.white).toARGB32();
                  _config.tagBarColor ??= Colors.white.toARGB32();
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDefaultPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('筛选栏默认状态'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('折叠'),
              trailing: !_config.expandFiltersByDefault ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.expandFiltersByDefault = false);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('展开'),
              trailing: _config.expandFiltersByDefault ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () {
                setState(() => _config.expandFiltersByDefault = true);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWallpaperPicker() async {
    final hasWallpaper = _config.wallpaperPath != null && _config.wallpaperPath!.isNotEmpty;
    if (hasWallpaper) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('选择图片'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickWallpaperImage();
                },
              ),
              ListTile(
                title: const Text('删除壁纸'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _config.wallpaperPath = null);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      await _pickWallpaperImage();
    }
  }

  Future<void> _pickWallpaperImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() => _config.wallpaperPath = path);
      }
    }
  }

  void _showNumberPickerDialog(String title, double currentValue, double min, double max, ValueChanged<double> onChanged, {bool isPercentage = false}) {
    double value = currentValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: (v) => setState(() => value = v),
                ),
                Text(
                  isPercentage ? '${value.round()}%' : value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  onChanged(value);
                  Navigator.pop(ctx);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showColorPicker(String title, Color currentColor, ValueChanged<Color> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;

    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;
    bool isEditingColorCode = false;

    final colorController = TextEditingController(
      text: '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    final colorFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

          final colorHex = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
          if (!isEditingColorCode && colorController.text != colorHex) {
            colorController.text = colorHex;
            colorController.selection = TextSelection.collapsed(offset: colorHex.length);
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 色相滑块
                  _buildColorSlider(
                    label: '色相',
                    sliderValue: hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) {
                      colorFocusNode.unfocus();
                      setDialogState(() {
                        isEditingColorCode = false;
                        hue = v;
                      });
                    },
                    displayValue: hue.round().toString(),
                    gradientColors: [
                      const Color(0xFFFF0000),
                      const Color(0xFFFFFF00),
                      const Color(0xFF00FF00),
                      const Color(0xFF00FFFF),
                      const Color(0xFF0000FF),
                      const Color(0xFFFF00FF),
                      const Color(0xFFFF0000),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 饱和度滑块
                  _buildColorSlider(
                    label: '饱和度',
                    sliderValue: saturation,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      colorFocusNode.unfocus();
                      setDialogState(() {
                        isEditingColorCode = false;
                        saturation = v;
                      });
                    },
                    displayValue: '${(saturation * 100).round()}%',
                    gradientColors: [
                      HSVColor.fromAHSV(1.0, hue, 0, value).toColor(),
                      HSVColor.fromAHSV(1.0, hue, 1, value).toColor(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 明度滑块
                  _buildColorSlider(
                    label: '明度',
                    sliderValue: value,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      colorFocusNode.unfocus();
                      setDialogState(() {
                        isEditingColorCode = false;
                        value = v;
                      });
                    },
                    displayValue: '${(value * 100).round()}%',
                    gradientColors: [
                      HSVColor.fromAHSV(1.0, hue, saturation, 0).toColor(),
                      HSVColor.fromAHSV(1.0, hue, saturation, 1).toColor(),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController,
                          focusNode: colorFocusNode,
                          decoration: InputDecoration(
                            hintText: '#RRGGBB',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          onTap: () {
                            isEditingColorCode = true;
                          },
                          onChanged: (text) {
                            final color = _parseColor(text);
                            if (color == null) return;
                            final hsv = HSVColor.fromColor(color);
                            setDialogState(() {
                              hue = hsv.hue;
                              saturation = hsv.saturation;
                              value = hsv.value;
                            });
                          },
                          onSubmitted: (text) {
                            final color = _parseColor(text);
                            if (color == null) return;
                            final hsv = HSVColor.fromColor(color);
                            setDialogState(() {
                              hue = hsv.hue;
                              saturation = hsv.saturation;
                              value = hsv.value;
                              isEditingColorCode = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          '取消',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          onChanged(
                            _parseColor(colorController.text) ?? selectedColor,
                          );
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          '确定',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      colorController.dispose();
      colorFocusNode.dispose();
    });
  }

  Color? _parseColor(String text) {
    var value = text.trim();
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    if (value.toLowerCase().startsWith('0x')) {
      value = value.substring(2);
    }

    if (value.length != 6 && value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(value.length == 6 ? parsed + 0xFF000000 : parsed);
  }

  Widget _buildColorSlider({
    required String label,
    required double sliderValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
    required List<Color> gradientColors,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 24,
                  trackShape: const _FullWidthSliderTrackShape(),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(
                  value: sliderValue,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            displayValue,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// 书籍信息管理页面
class BookInfoManagePage extends StatefulWidget {
  const BookInfoManagePage({super.key});
  @override
  State<BookInfoManagePage> createState() => _BookInfoManagePageState();
}

class _BookInfoManagePageState extends State<BookInfoManagePage> {
  final List<BookInfoItem> _items = [
    BookInfoItem('封面', true),
    BookInfoItem('书名', true),
    BookInfoItem('作者', true),
    BookInfoItem('简介', true),
    BookInfoItem('最新章节', true),
    BookInfoItem('更新时间', true),
    BookInfoItem('阅读进度', true),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var item in _items) {
        item.visible = prefs.getBool('bookInfo_${item.title}') ?? true;
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (var item in _items) {
      await prefs.setBool('bookInfo_${item.title}', item.visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍信息管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () {
              _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置',
            onPressed: () => setState(() {
              for (var item in _items) {
                item.visible = true;
              }
            }),
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(16),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _items.removeAt(oldIndex);
            _items.insert(newIndex, item);
          });
        },
        children: _items.map((item) => ListTile(
          key: ValueKey(item.title),
          title: Text(item.title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AndroidSwitch(
                value: item.visible,
                onChanged: (v) => setState(() => item.visible = v),
                accentColor: Theme.of(context).colorScheme.secondary,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              const Icon(Icons.drag_handle),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class BookInfoItem {
  String title;
  bool visible;
  BookInfoItem(this.title, this.visible);
}

// 气泡管理页面
class BubbleManagePage extends StatefulWidget {
  const BubbleManagePage({super.key});
  @override
  State<BubbleManagePage> createState() => _BubbleManagePageState();
}

class _BubbleManagePageState extends State<BubbleManagePage> {
  double _sizeScale = 1.0;
  Color _dayColor = const Color(0xFFF5F5F5);
  Color _nightColor = const Color(0xFF424242);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sizeScale = prefs.getDouble('bubbleSizeScale') ?? 1.0;
      _dayColor = Color(prefs.getInt('bubbleDayColor') ?? 0xFFF5F5F5);
      _nightColor = Color(prefs.getInt('bubbleNightColor') ?? 0xFF424242);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bubbleSizeScale', _sizeScale);
    await prefs.setInt('bubbleDayColor', _dayColor.toARGB32());
    await prefs.setInt('bubbleNightColor', _nightColor.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('气泡管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: () {
              _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('大小倍率'),
            subtitle: Slider(
              value: _sizeScale,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) => setState(() => _sizeScale = v),
            ),
            trailing: Text(_sizeScale.toStringAsFixed(1)),
          ),
          ListTile(
            leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: _dayColor, borderRadius: BorderRadius.circular(8))),
            title: const Text('日间颜色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showColorPicker('日间颜色', _dayColor, (c) => setState(() => _dayColor = c)),
          ),
          ListTile(
            leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: _nightColor, borderRadius: BorderRadius.circular(8))),
            title: const Text('夜间颜色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showColorPicker('夜间颜色', _nightColor, (c) => setState(() => _nightColor = c)),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(String title, Color currentColor, ValueChanged<Color> onChanged) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
            Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
            Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
            Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
            Colors.brown, Colors.grey, Colors.blueGrey, Colors.black, Colors.white,
          ].map((c) => GestureDetector(
            onTap: () {
              onChanged(c);
              Navigator.pop(ctx);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: c == currentColor ? Theme.of(context).colorScheme.primary : Colors.grey,
                  width: c == currentColor ? 3 : 1,
                ),
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }
}

// 封面设置页面 - 参考原版 legado CoverConfigFragment
class CoverConfigPage extends StatefulWidget {
  const CoverConfigPage({super.key});
  @override
  State<CoverConfigPage> createState() => _CoverConfigPageState();
}

class _CoverConfigPageState extends State<CoverConfigPage> {
  // 通用设置
  bool _loadCoverOnlyWifi = false;
  bool _loadCoverHighQuality = false;
  bool _useDefaultCover = false;
  // 日间
  String _coverCollectionDay = '';
  String _coverCollectionModeDay = 'random';
  bool _coverShowName = true;
  bool _coverShowAuthor = true;
  String _defaultCover = '';
  // 夜间
  String _coverCollectionNight = '';
  String _coverCollectionModeNight = 'random';
  bool _coverShowNameN = true;
  bool _coverShowAuthorN = true;
  String _defaultCoverDark = '';
  // 显示作者的真实状态（用户手动设置的，不受显示书名影响）
  bool _coverShowAuthorReal = true;
  bool _coverShowAuthorNReal = true;
  // 图集名称缓存
  String _coverCollectionDayName = '';
  String _coverCollectionNightName = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _loadCoverOnlyWifi = prefs.getBool('loadCoverOnlyWifi') ?? false;
      _loadCoverHighQuality = prefs.getBool('loadCoverHighQuality') ?? false;
      _useDefaultCover = prefs.getBool('useDefaultCover') ?? false;
      _coverCollectionDay = prefs.getString('coverCollectionDay') ?? '';
      _coverCollectionModeDay = prefs.getString('coverCollectionModeDay') ?? 'random';
      _coverShowName = prefs.getBool('coverShowName') ?? true;
      // 读取真实状态
      _coverShowAuthorReal = prefs.getBool('coverShowAuthorReal') ?? true;
      // 如果显示书名关闭，显示作者强制关闭；否则恢复真实状态
      _coverShowAuthor = _coverShowName ? _coverShowAuthorReal : false;
      _defaultCover = prefs.getString('defaultCover') ?? '';
      _coverCollectionNight = prefs.getString('coverCollectionNight') ?? '';
      _coverCollectionModeNight = prefs.getString('coverCollectionModeNight') ?? 'random';
      _coverShowNameN = prefs.getBool('coverShowNameN') ?? true;
      // 读取真实状态
      _coverShowAuthorNReal = prefs.getBool('coverShowAuthorNReal') ?? true;
      // 如果显示书名关闭，显示作者强制关闭；否则恢复真实状态
      _coverShowAuthorN = _coverShowNameN ? _coverShowAuthorNReal : false;
      _defaultCoverDark = prefs.getString('defaultCoverDark') ?? '';
    });
    // 加载图集名称
    await _loadCollectionNames();
  }

  Future<void> _loadCollectionNames() async {
    if (_coverCollectionDay.isNotEmpty) {
      final dayCollections = await CoverCollectionManager.instance.getCollections(false);
      final dayColl = dayCollections.where((c) => c.id == _coverCollectionDay).firstOrNull;
      if (mounted && dayColl != null) {
        setState(() => _coverCollectionDayName = dayColl.name);
      }
    }
    if (_coverCollectionNight.isNotEmpty) {
      final nightCollections = await CoverCollectionManager.instance.getCollections(true);
      final nightColl = nightCollections.where((c) => c.id == _coverCollectionNight).firstOrNull;
      if (mounted && nightColl != null) {
        setState(() => _coverCollectionNightName = nightColl.name);
      }
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await CoverConfigService.instance.reload();
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    await CoverConfigService.instance.reload();
  }

  Future<void> _removePref(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await CoverConfigService.instance.reload();
  }

  String _getModeLabel(String mode) {
    switch (mode) {
      case 'random': return '随机';
      case 'sequence': return '顺序';
      case 'mixed': return '混合';
      default: return '随机';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('封面设置'),
      ),
      body: ListView(
        children: [
          // 仅WiFi加载封面
          _buildSwitchItem(
            title: '仅WiFi加载',
            subtitle: '仅WiFi网络下加载封面图片',
            value: _loadCoverOnlyWifi,
            onChanged: (v) {
              setState(() => _loadCoverOnlyWifi = v);
              _saveBool('loadCoverOnlyWifi', v);
            },
          ),

          // 加载高清封面
          _buildSwitchItem(
            title: '加载高清封面',
            subtitle: '开启后使用封面原图，关闭时优先加载缩略图',
            value: _loadCoverHighQuality,
            onChanged: (v) {
              setState(() => _loadCoverHighQuality = v);
              _saveBool('loadCoverHighQuality', v);
            },
          ),

          // 封面规则
          _buildListItem(
            title: '封面规则',
            subtitle: '进入详情页时使用封面规则重新获取封面',
            onTap: () => _showCoverRuleDialog(),
          ),

          // 总是使用默认封面
          _buildSwitchItem(
            title: '总是使用默认封面',
            subtitle: '总是显示默认封面（不显示网络封面）',
            value: _useDefaultCover,
            onChanged: (v) {
              setState(() => _useDefaultCover = v);
              _saveBool('useDefaultCover', v);
            },
          ),

          // 封面图集
          _buildListItem(
            title: '封面图集',
            onTap: () => _navigateToCoverCollectionManage(),
          ),

          const SizedBox(height: 8),

          // 日间主题
          _buildCategoryHeader('日间主题'),

          _buildListItem(
            title: '选用图集',
            subtitle: _coverCollectionDayName.isEmpty ? '无' : _coverCollectionDayName,
            onTap: () => _selectCoverCollection(false),
          ),

          _buildListItem(
            title: '封面模式',
            subtitle: _getModeLabel(_coverCollectionModeDay),
            onTap: () => _selectCoverMode(false),
          ),

          _buildSwitchItem(
            title: '显示书名',
            subtitle: '封面上显示书名',
            value: _coverShowName,
            onChanged: (v) {
              setState(() {
                _coverShowName = v;
                // 显示书名关闭时，显示作者强制关闭
                // 显示书名开启时，显示作者恢复真实状态
                if (!v) {
                  _coverShowAuthor = false;
                } else {
                  _coverShowAuthor = _coverShowAuthorReal;
                }
              });
              _saveBool('coverShowName', v);
              // 同步保存显示作者状态
              _saveBool('coverShowAuthor', _coverShowAuthor);
            },
          ),

          _buildSwitchItem(
            title: '显示作者',
            subtitle: '封面上显示作者',
            value: _coverShowAuthor,
            enabled: _coverShowName,
            onChanged: (v) {
              setState(() {
                _coverShowAuthor = v;
                _coverShowAuthorReal = v; // 保存真实状态
              });
              _saveBool('coverShowAuthor', v);
              _saveBool('coverShowAuthorReal', v); // 保存真实状态
            },
          ),

          _buildListItem(
            title: '默认封面',
            subtitle: _defaultCover.isEmpty ? '选择图片' : _defaultCover.split('/').last,
            onTap: () => _selectDefaultCover(false),
          ),

          const SizedBox(height: 8),

          // 夜间主题
          _buildCategoryHeader('夜间主题'),

          _buildListItem(
            title: '选用图集',
            subtitle: _coverCollectionNightName.isEmpty ? '无' : _coverCollectionNightName,
            onTap: () => _selectCoverCollection(true),
          ),

          _buildListItem(
            title: '封面模式',
            subtitle: _getModeLabel(_coverCollectionModeNight),
            onTap: () => _selectCoverMode(true),
          ),

          _buildSwitchItem(
            title: '显示书名',
            subtitle: '封面上显示书名',
            value: _coverShowNameN,
            onChanged: (v) {
              setState(() {
                _coverShowNameN = v;
                // 显示书名关闭时，显示作者强制关闭
                // 显示书名开启时，显示作者恢复真实状态
                if (!v) {
                  _coverShowAuthorN = false;
                } else {
                  _coverShowAuthorN = _coverShowAuthorNReal;
                }
              });
              _saveBool('coverShowNameN', v);
              // 同步保存显示作者状态
              _saveBool('coverShowAuthorN', _coverShowAuthorN);
            },
          ),

          _buildSwitchItem(
            title: '显示作者',
            subtitle: '封面上显示作者',
            value: _coverShowAuthorN,
            enabled: _coverShowNameN,
            onChanged: (v) {
              setState(() {
                _coverShowAuthorN = v;
                _coverShowAuthorNReal = v; // 保存真实状态
              });
              _saveBool('coverShowAuthorN', v);
              _saveBool('coverShowAuthorNReal', v); // 保存真实状态
            },
          ),

          _buildListItem(
            title: '默认封面',
            subtitle: _defaultCoverDark.isEmpty ? '选择图片' : _defaultCoverDark.split('/').last,
            onTap: () => _selectDefaultCover(true),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 构建分类标题 - 参考原版 view_preference_category.xml
  /// 使用强调色（accentColor）
  Widget _buildCategoryHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.secondary, // 使用强调色
        ),
      ),
    );
  }

  /// 构建列表项 - 参考原版 view_preference.xml
  /// 标题 16sp，副标题 14sp，高度 60dp，padding 10dp
  Widget _buildListItem({
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF212121),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : const Color(0xFF757575),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white54 : const Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }

  /// 构建开关项 - 参考原版 view_preference.xml + SwitchPreference
  /// 标题 16sp，副标题 14sp，高度 60dp，padding 10dp
  Widget _buildSwitchItem({
    required String title,
    String? subtitle,
    required bool value,
    bool enabled = true,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 使用强调色（secondary）而不是主色（primary），参考原版 SwitchPreference
    final accentColor = Theme.of(context).colorScheme.secondary;

    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: enabled
                          ? (isDark ? Colors.white : const Color(0xFF212121))
                          : (isDark ? Colors.white38 : const Color(0xFFBDBDBD)),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: enabled
                              ? (isDark ? Colors.white70 : const Color(0xFF757575))
                              : (isDark ? Colors.white24 : const Color(0xFFBDBDBD)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 原版Android SwitchCompat风格 - 自定义绘制thumb和track
            AndroidSwitch(
              value: value,
              onChanged: onChanged,
              accentColor: accentColor,
              isDark: isDark,
              enabled: enabled,
            ),
          ],
        ),
      ),
    );
  }

  /// 封面规则配置对话框 - 参考原版 CoverRuleConfigDialog
  void _showCoverRuleDialog() async {
    final rule = CoverConfigService.instance.coverRule;
    bool enable = rule.enable;
    String searchUrl = rule.searchUrl;
    String coverRule = rule.coverRule;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          backgroundColor: Theme.of(ctx).brightness == Brightness.dark
              ? const Color(0xFF424242)
              : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏 - 与AlertDialog一致，无背景色
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Text(
                    '封面规则',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF212121),
                    ),
                  ),
                ),

                // 内容区域
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 启用开关
                        Row(
                          children: [
                            Checkbox(
                              value: enable,
                              activeColor: Theme.of(ctx).colorScheme.primary,
                              onChanged: (v) => setDialogState(() => enable = v ?? true),
                            ),
                            Text('启用',
                                style: TextStyle(
                                  color: Theme.of(ctx).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF212121),
                                )),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 搜索URL输入框
                        TextField(
                          controller: TextEditingController(text: searchUrl),
                          style: TextStyle(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF212121),
                          ),
                          decoration: InputDecoration(
                            labelText: '搜索URL',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelStyle: TextStyle(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? Colors.white70
                                  : const Color(0xFF757575),
                            ),
                          ),
                          maxLines: 2,
                          onChanged: (v) => searchUrl = v,
                        ),

                        const SizedBox(height: 12),

                        // 封面规则输入框
                        TextField(
                          controller: TextEditingController(text: coverRule),
                          style: TextStyle(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF212121),
                          ),
                          decoration: InputDecoration(
                            labelText: '封面规则',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelStyle: TextStyle(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? Colors.white70
                                  : const Color(0xFF757575),
                            ),
                          ),
                          maxLines: 8,
                          onChanged: (v) => coverRule = v,
                        ),
                      ],
                    ),
                  ),
                ),

                // 底部按钮区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          // 恢复默认
                          final messenger = ScaffoldMessenger.of(context);
                          await CoverConfigService.instance.deleteCoverRule();
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('已恢复默认封面规则')),
                          );
                        },
                        child: Text(
                          '默认',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('取消',
                                style: TextStyle(
                                  color: Theme.of(ctx).brightness == Brightness.dark
                                      ? Colors.white70
                                      : const Color(0xFF757575),
                                )),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              if (searchUrl.isEmpty || coverRule.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('搜索URL和封面规则不能为空')),
                                );
                                return;
                              }
                              final newRule = CoverRule(
                                enable: enable,
                                searchUrl: searchUrl,
                                coverRule: coverRule,
                              );
                              await CoverConfigService.instance.saveCoverRule(newRule);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                const SnackBar(content: Text('封面规则已保存')),
                              );
                            },
                            child: Text(
                              '确定',
                              style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectCoverCollection(bool isNight) async {
    final collections = await CoverCollectionManager.instance.getCollections(isNight);
    final selectedId = isNight ? _coverCollectionNight : _coverCollectionDay;

    if (!mounted) return;

    final items = ['无'];
    items.addAll(collections.map((c) => '${c.name} (${c.images.length}张)'));
    int selectedIndex = selectedId.isEmpty ? 0 : collections.indexWhere((c) => c.id == selectedId) + 1;

    final result = await CommonWidgets.showSelectorDialog(
      context,
      title: '选用图集',
      items: items,
      selectedIndex: selectedIndex,
    );

    if (result != null) {
      final selected = result == 0 ? null : (result - 1 < collections.length ? collections[result - 1] : null);
      await CoverCollectionManager.instance.setSelectedCollection(selected?.id, isNight);
      setState(() {
        if (isNight) {
          _coverCollectionNight = selected?.id ?? '';
          _coverCollectionNightName = selected?.name ?? '';
        } else {
          _coverCollectionDay = selected?.id ?? '';
          _coverCollectionDayName = selected?.name ?? '';
        }
      });
    }
  }

  /// 导航到封面图集管理页 - 使用流畅的页面过渡
  void _navigateToCoverCollectionManage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CoverCollectionManagePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 使用淡入淡出过渡，更流畅
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    ).then((_) {
      // 返回后刷新图集名称
      _loadCollectionNames();
    });
  }

  void _selectCoverMode(bool isNight) {
    final modes = ['随机', '顺序', '混合'];
    final modeValues = ['random', 'sequence', 'mixed'];
    final currentMode = isNight ? _coverCollectionModeNight : _coverCollectionModeDay;
    int selectedIndex = modeValues.indexOf(currentMode);

    CommonWidgets.showSelectorDialog(
      context,
      title: '封面模式',
      items: modes,
      selectedIndex: selectedIndex,
    ).then((result) {
      if (result != null) {
        final mode = modeValues[result];
        if (isNight) {
          setState(() => _coverCollectionModeNight = mode);
          _saveString('coverCollectionModeNight', mode);
        } else {
          setState(() => _coverCollectionModeDay = mode);
          _saveString('coverCollectionModeDay', mode);
        }
      }
    });
  }

  void _selectDefaultCover(bool isNight) {
    final currentPath = isNight ? _defaultCoverDark : _defaultCover;

    if (currentPath.isEmpty) {
      _pickCoverImage(isNight);
    } else {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(ctx);
                  final key = isNight ? 'defaultCoverDark' : 'defaultCover';
                  _removePref(key);
                  setState(() {
                    if (isNight) {
                      _defaultCoverDark = '';
                    } else {
                      _defaultCover = '';
                    }
                  });
                },
              ),
              ListTile(
                title: const Text('选择图片'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCoverImage(isNight);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _pickCoverImage(bool isNight) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final key = isNight ? 'defaultCoverDark' : 'defaultCover';
        await _saveString(key, path);
        setState(() {
          if (isNight) {
            _defaultCoverDark = path;
          } else {
            _defaultCover = path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }
}

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

/// 导航项数据类 - 参考原版 NavigationBarIconConfig.NavItem
class _NavItem {
  final String key;
  final String title;
  final IconData icon;

  const _NavItem(this.key, this.title, this.icon);
}
