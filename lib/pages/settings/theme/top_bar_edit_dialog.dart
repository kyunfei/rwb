import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'theme_slider_track_shape.dart';
import 'top_bar_config.dart';

class TopBarEditDialog extends StatefulWidget {
  final TopBarConfig config;
  final bool isEdit;
  final Future<void> Function(TopBarConfig) onSave;

  const TopBarEditDialog({
    super.key,
    required this.config,
    required this.isEdit,
    required this.onSave,
  });

  @override
  State<TopBarEditDialog> createState() => _TopBarEditDialogState();
}

class _TopBarEditDialogState extends State<TopBarEditDialog> {
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
                  trackShape: const FullWidthSliderTrackShape(),
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
