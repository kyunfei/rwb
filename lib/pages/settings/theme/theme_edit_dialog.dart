// 主题编辑对话框 - 完全参考 legado-main 的 dialog_theme_package_edit.xml
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'theme_package_config.dart';
import 'theme_slider_track_shape.dart';

class ThemeEditDialog extends StatefulWidget {
  final ThemeConfig theme;
  final bool isEdit;
  final Future<void> Function(ThemeConfig) onSave;

  const ThemeEditDialog({
    super.key,
    required this.theme,
    required this.isEdit,
    required this.onSave,
  });

  @override
  State<ThemeEditDialog> createState() => _ThemeEditDialogState();
}

class _ThemeEditDialogState extends State<ThemeEditDialog> {
  late ThemeConfig _theme;
  int _selectedTab = 0;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _theme = widget.theme.copy();
    _nameController.text = _theme.name;
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
    // 完全匹配原版 legado-main 的对话框大小
    // EDIT_DIALOG_WIDTH_RATIO = 0.94f
    // EDIT_DIALOG_HEIGHT_RATIO = 0.68f (屏幕高度 >= 1600)
    // EDIT_DIALOG_HEIGHT_RATIO_COMPACT = 0.74f (屏幕高度 < 1600)
    final dialogWidth = screenWidth * 0.94;
    final dialogHeight = screenHeight < 1600 ? screenHeight * 0.74 : screenHeight * 0.68;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // ui_panel_radius = 10dp
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
                widget.isEdit ? '编辑主题' : '添加主题',
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
                    // 名称输入框 - 高度 44dp
                    Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: '主题名称',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                        style: const TextStyle(fontSize: 15),
                        onChanged: (v) => _theme.name = v,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 分组标签 - 高度 42dp
                    Container(
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton('颜色', 0),
                          _buildTabButton('图片', 1),
                          _buildTabButton('界面', 2),
                          _buildTabButton('字体', 3),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 内容区域
                    _buildTabContent(),
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
                  // 取消按钮 - 宽度 96dp, 高度 40dp
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

                  // 确认按钮 - 宽度 96dp, 高度 40dp
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
                        await widget.onSave(_theme);
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

  Widget _buildTabButton(String label, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildColorGroup();
      case 1:
        return _buildImageGroup();
      case 2:
        return _buildInterfaceGroup();
      case 3:
        return _buildFontGroup();
      default:
        return const SizedBox();
    }
  }

  // 颜色分组
  Widget _buildColorGroup() {
    return Column(
      children: [
        _buildColorOption('主色', _theme.primaryColor, (c) => setState(() => _theme.primaryColor = c)),
        _buildColorOption('强调色', _theme.accentColor, (c) => setState(() => _theme.accentColor = c)),
        _buildColorOption('背景色', _theme.backgroundColor, (c) => setState(() => _theme.backgroundColor = c)),
        _buildColorOption('底部背景色', _theme.navBarColor, (c) => setState(() => _theme.navBarColor = c)),
      ],
    );
  }

  // 图片分组
  Widget _buildImageGroup() {
    return Column(
      children: [
        _buildImageOption('主背景图片', _theme.mainBgImage, _theme.bgImageBlur, true, (path) => setState(() => _theme.mainBgImage = path), (blur) => setState(() => _theme.bgImageBlur = blur)),
        _buildImageOption('书籍信息背景', _theme.bookInfoBgImage, null, false, (path) => setState(() => _theme.bookInfoBgImage = path), null),
        _buildImageOption('面板背景', _theme.panelBgImage, null, false, (path) => setState(() => _theme.panelBgImage = path), null),
        _buildSelectOption('面板背景模式', _theme.panelBgMode == 'crop' ? '裁剪' : '适应', () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('裁剪'),
                    onTap: () {
                      setState(() => _theme.panelBgMode = 'crop');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    title: const Text('适应'),
                    onTap: () {
                      setState(() => _theme.panelBgMode = 'fit');
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // 界面分组
  Widget _buildInterfaceGroup() {
    return Column(
      children: [
        _buildSliderOption('圆角比例', _theme.cornerScale, 0.0, 3.0, (v) => setState(() => _theme.cornerScale = v)),
        _buildSliderOption('布局透明度', _theme.layoutAlpha.toDouble(), 0, 100, (v) => setState(() => _theme.layoutAlpha = v.round()), isPercentage: true),
        _buildColorOption('面板边框色', _theme.panelBorderColor ?? Colors.transparent, (c) => setState(() => _theme.panelBorderColor = c), canDisable: true),
        _buildSliderOption('边框透明度', _theme.panelBorderAlpha.toDouble(), 0, 100, (v) => setState(() => _theme.panelBorderAlpha = v.round()), isPercentage: true),
        _buildSwitchOption('搜索跟随主题', _theme.searchFollow, (v) => setState(() => _theme.searchFollow = v)),
        _buildSwitchOption('回复跟随主题', _theme.replyFollow, (v) => setState(() => _theme.replyFollow = v)),
      ],
    );
  }

  // 字体分组
  Widget _buildFontGroup() {
    return Column(
      children: [
        _buildSliderOption('字体缩放', _theme.fontScale.toDouble(), 8, 16, (v) => setState(() => _theme.fontScale = v.round()), showDefault: true, defaultValue: 10),
        _buildSelectOption('UI字体', _theme.uiFont ?? '默认', () => _showFontSelector(true)),
        _buildSelectOption('标题字体', _theme.titleFont ?? '默认', () => _showFontSelector(false)),
      ],
    );
  }

  // 选项行 - 高度 44dp
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

  // 颜色选项
  Widget _buildColorOption(String title, Color color, ValueChanged<Color> onChanged, {bool canDisable = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showColorPicker(title, color, onChanged, canDisable: canDisable),
        child: Row(
          children: [
            // 标题
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            // 颜色预览 - 22dp x 22dp
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

            // 颜色值 - 宽度 132dp
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

  void _showColorPicker(String title, Color currentColor, ValueChanged<Color> onChanged, {bool canDisable = false}) {
    if (canDisable) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
    
    // 初始 HSV 值
    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;
    bool isEditingColorCode = false;
    
    // 颜色编码输入控制器
    final colorController = TextEditingController(
      text: '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    final colorFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
          
          // 滑动调色时同步编码；手动输入期间不覆盖用户正在编辑的内容。
          final colorHex = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
          if (!isEditingColorCode && colorController.text != colorHex) {
            colorController.text = colorHex;
            colorController.selection = TextSelection.collapsed(offset: colorHex.length);
          }
          
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10), // ui_panel_radius = 10dp
            ),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 颜色预览 - 大方块
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
                      const Color(0xFFFF0000), // 红
                      const Color(0xFFFFFF00), // 黄
                      const Color(0xFF00FF00), // 绿
                      const Color(0xFF00FFFF), // 青
                      const Color(0xFF0000FF), // 蓝
                      const Color(0xFFFF00FF), // 品红
                      const Color(0xFFFF0000), // 红
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
                  
                  // 按钮
                  Row(
                    children: [
                      // 颜色编码输入框
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
                             if (color != null) {
                               final hsv = HSVColor.fromColor(color);
                               setDialogState(() {
                                 hue = hsv.hue;
                                 saturation = hsv.saturation;
                                 value = hsv.value;
                                 isEditingColorCode = false;
                               });
                             }
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
  
  /// 解析颜色字符串，支持 #RRGGBB、#AARRGGBB、RRGGBB 等格式
  Color? _parseColor(String text) {
    text = text.trim();
    if (text.isEmpty) return null;
    
    // 移除 # 前缀
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    
    // 移除 0x 前缀
    if (text.toLowerCase().startsWith('0x')) {
      text = text.substring(2);
    }
    
    try {
      int colorValue;
      if (text.length == 6) {
        // RRGGBB 格式，添加完全不透明的 Alpha
        colorValue = int.parse(text, radix: 16) + 0xFF000000;
      } else if (text.length == 8) {
        // AARRGGBB 格式
        colorValue = int.parse(text, radix: 16);
      } else {
        return null;
      }
      return Color(colorValue);
    } catch (e) {
      return null;
    }
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
              // 渐变背景
              Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 滑块
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

  // 图片选项
  Widget _buildImageOption(String title, String? path, int? blur, bool showBlur, ValueChanged<String?> onPathChanged, ValueChanged<int>? onBlurChanged) {
    final colorScheme = Theme.of(context).colorScheme;
    String valueText;
    if (path == null || path.isEmpty) {
      if (showBlur && blur != null) {
        valueText = '未设置 (模糊: $blur)';
      } else {
        valueText = '未设置';
      }
    } else {
      final fileName = path.split('/').last;
      if (showBlur && blur != null) {
        valueText = '$fileName (模糊: $blur)';
      } else {
        valueText = fileName;
      }
    }

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showImageActions(title, path, blur, showBlur, onPathChanged, onBlurChanged),
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageActions(String title, String? currentPath, int? currentBlur, bool showBlur, ValueChanged<String?> onPathChanged, ValueChanged<int>? onBlurChanged) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBlur)
              ListTile(
                title: const Text('设置模糊度'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlurDialog(currentBlur ?? 0, onBlurChanged!);
                },
              ),
            ListTile(
              title: const Text('选择图片'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowCompression: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  final path = result.files.first.path;
                  if (path != null) {
                    onPathChanged(path);
                  }
                }
              },
            ),
            ListTile(
              title: const Text('输入URL'),
              onTap: () {
                Navigator.pop(ctx);
                _showUrlInputDialog(title, onPathChanged);
              },
            ),
            if (currentPath != null && currentPath.isNotEmpty)
              ListTile(
                title: const Text('清除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  onPathChanged(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showBlurDialog(int currentBlur, ValueChanged<int> onBlurChanged) {
    int blur = currentBlur;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('背景图片模糊度'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: blur.toDouble(),
                  min: 0,
                  max: 25,
                  divisions: 25,
                  onChanged: (v) => setState(() => blur = v.round()),
                ),
                Text('模糊度: $blur'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  onBlurChanged(blur);
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

  void _showUrlInputDialog(String title, ValueChanged<String?> onPathChanged) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入图片URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onPathChanged(controller.text.isEmpty ? null : controller.text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 滑块选项
  Widget _buildSliderOption(String title, double value, double min, double max, ValueChanged<double> onChanged, {bool isPercentage = false, bool showDefault = false, double? defaultValue}) {
    final colorScheme = Theme.of(context).colorScheme;
    String valueText;
    if (showDefault && defaultValue != null && value == defaultValue) {
      valueText = '默认';
    } else if (isPercentage) {
      valueText = '${value.round()}%';
    } else if (value == value.roundToDouble()) {
      valueText = value.round().toString();
    } else {
      valueText = value.toStringAsFixed(1);
    }

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => _showNumberPickerDialog(title, value, min, max, onChanged, isPercentage: isPercentage, showDefault: showDefault, defaultValue: defaultValue),
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

  void _showNumberPickerDialog(String title, double currentValue, double min, double max, ValueChanged<double> onChanged, {bool isPercentage = false, bool showDefault = false, double? defaultValue}) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          double value = currentValue;
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
              if (showDefault && defaultValue != null)
                TextButton(
                  onPressed: () {
                    onChanged(defaultValue);
                    Navigator.pop(ctx);
                  },
                  child: const Text('默认'),
                ),
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

  // 选择选项
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

  // 开关选项
  Widget _buildSwitchOption(String title, bool value, ValueChanged<bool> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildOptionRow(
      child: GestureDetector(
        onTap: () => onChanged(!value),
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
                value ? '启用' : '禁用',
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

  void _showFontSelector(bool isUiFont) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('默认字体'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  if (isUiFont) {
                    _theme.uiFont = null;
                  } else {
                    _theme.titleFont = null;
                  }
                });
              },
            ),
            ListTile(
              title: const Text('选择字体文件'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['ttf', 'otf'],
                  allowCompression: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  final path = result.files.first.path;
                  if (path != null) {
                    setState(() {
                      if (isUiFont) {
                        _theme.uiFont = path;
                      } else {
                        _theme.titleFont = path;
                      }
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
