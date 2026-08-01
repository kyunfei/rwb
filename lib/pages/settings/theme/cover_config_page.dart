import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/cover_config_service.dart';
import '../../../widgets/android_switch.dart';
import '../../../widgets/common_widgets.dart';
import 'cover_collection_manage_page.dart';

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
