import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/android_switch.dart';
import 'theme/book_info_manage_page.dart';
import 'theme/bubble_manage_page.dart';
import 'theme/cover_config_page.dart';
import 'theme/navigation_bar_manage_page.dart';
import 'theme/theme_manage_page.dart';
import 'theme/top_bar_manage_page.dart';

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
