import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'navigation_bar_config.dart';
import 'theme_slider_track_shape.dart';

/// 导航项数据类 - 参考原版 NavigationBarIconConfig.NavItem
class NavItem {
  final String key;
  final String title;
  final IconData icon;

  const NavItem(this.key, this.title, this.icon);
}

// 底栏包编辑对话框 - 参考 legado-main 的编辑对话框
class NavBarEditDialog extends StatefulWidget {
  final NavigationBarConfig config;
  final bool isEdit;
  final Future<void> Function(NavigationBarConfig) onSave;

  const NavBarEditDialog({
    super.key,
    required this.config,
    required this.isEdit,
    required this.onSave,
  });

  @override
  State<NavBarEditDialog> createState() => _NavBarEditDialogState();
}

class _NavBarEditDialogState extends State<NavBarEditDialog> {
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

  // 导航项列表：与主页三 Tab（书架 / 书城 / 我的）对齐
  // icons map 里若仍残留旧 key（rss/ai）可忽略，不影响运行
  static const _navItems = [
    NavItem('bookshelf', '书架', Icons.menu_book),
    NavItem('discovery', '书城', Icons.storefront),
    NavItem('my', '我的', Icons.person),
  ];

  List<Widget> _buildIconRows() {
    final colorScheme = Theme.of(context).colorScheme;

    return _navItems.map((item) {
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

  Widget _buildIconButton(NavItem item, bool selected) {
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

  void _showIconOptions(NavItem item, bool selected) {
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

  Future<void> _pickIconImage(NavItem item, bool selected) async {
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
                  trackShape: const FullWidthSliderTrackShape(),
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
