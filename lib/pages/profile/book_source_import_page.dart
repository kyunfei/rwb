import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/book_source_import_service.dart';
import '../../services/source_import_failure.dart';
import '../../services/source_import_logic.dart';
import '../../services/source_subscribe_service.dart';
import '../../utils/design_tokens.dart';

/// 书源导入页面
/// 支持网络导入、本地文件导入、剪贴板文本导入
class BookSourceImportPage extends StatefulWidget {
  /// 外部传入的初始文本（如其他 App 分享来的 URL 或 JSON）
  final String? initialText;

  const BookSourceImportPage({super.key, this.initialText});

  @override
  State<BookSourceImportPage> createState() => _BookSourceImportPageState();
}

class _BookSourceImportPageState extends State<BookSourceImportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _urlController = TextEditingController();
  final _textController = TextEditingController();
  final _jsController = TextEditingController();
  bool _isImporting = false;
  bool _rememberSubscribe = true;
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      // 如果是 URL，填入 URL 标签；否则填入文本标签
      // _doImport 会自动尝试 JSON 和 JS 两种格式
      if (_looksLikeUrl(widget.initialText!)) {
        _urlController.text = widget.initialText!;
        _tabController.index = 0;
      } else {
        _tabController.index = 1;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _hideCurrentSnackBar();
    _tabController.dispose();
    _urlController.dispose();
    _textController.dispose();
    _jsController.dispose();
    super.dispose();
  }

  bool _looksLikeUrl(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('请输入书源地址');
      return;
    }
    await _doImport(url);
  }

  Future<void> _importFromText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showError('请输入书源 JSON 内容');
      return;
    }
    await _doImport(text);
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'js'],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isImporting = true);

      final file = result.files.first;
      final bytes = file.bytes ?? await _readFileBytes(file.path!);
      final ext = file.extension?.toLowerCase() ?? 'json';

      final importResult = await BookSourceImportService().importBytes(
        bytes,
        fileExtension: ext,
      );
      await _showResultAndPop(importResult);
    } catch (e, st) {
      debugPrint('文件导入失败: $e\n$st');
      _showError(describeSourceImportFailure(e));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<Uint8List> _readFileBytes(String path) async {
    // file_picker 在移动端已返回 bytes，Web 端也返回 bytes
    // 此方法作为后备：从文件路径读取字节（仅原生平台）
    if (kIsWeb) {
      throw StateError('当前平台不支持按路径读取文件');
    }
    try {
      final file = File(path);
      return await file.readAsBytes();
    } catch (e, st) {
      debugPrint('读取文件失败: $e\n$st');
      rethrow;
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _showError('剪贴板为空');
      return;
    }
    _textController.text = text;
    await _doImport(text);
  }

  Future<void> _doImport(String text) async {
    setState(() => _isImporting = true);
    try {
      final service = BookSourceImportService();
      BookSourceImportResult result;
      Object? jsonError;
      // 先尝试 JSON 格式，失败则按 JS 书源导入
      try {
        result = await service.importText(text);
      } catch (e, st) {
        jsonError = e;
        debugPrint('JSON 书源导入失败，尝试 JS: $e\n$st');
        // URL / 明确的网络与格式错误不必再走 JS 兜底，避免掩盖真实原因
        if (e is SourceImportException || looksLikeSubscribeUrl(text.trim())) {
          rethrow;
        }
        try {
          result = await service.importJsText(text);
        } catch (jsError, jsSt) {
          debugPrint('JS 书源导入也失败: $jsError\n$jsSt');
          // 优先展示更可读的 JSON 侧错误
          Error.throwWithStackTrace(jsonError, st);
        }
      }
      // 网络 URL 成功导入后记住订阅，便于一键更新
      if (_rememberSubscribe && looksLikeSubscribeUrl(text.trim())) {
        try {
          await SourceSubscribeService().add(text.trim(), importNow: false);
        } catch (e, st) {
          debugPrint('记住订阅地址失败: $e\n$st');
        }
      }
      await _showResultAndPop(result);
    } catch (e, st) {
      debugPrint('书源导入失败: $e\n$st');
      _showError(describeSourceImportFailure(e));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _showResultAndPop(BookSourceImportResult result) async {
    if (!mounted) return;
    final total = result.added + result.updated + result.unchanged;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入成功'),
        content: Text(
          '共处理 $total 条书源\n'
          '新增 ${result.added} 条\n'
          '更新 ${result.updated} 条\n'
          '跳过 ${result.unchanged} 条（本地已是最新）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, result);
  }

  void _showError(String msg) {
    final messenger = _messenger ?? ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _hideCurrentSnackBar() {
    (_messenger ?? ScaffoldMessenger.maybeOf(context))?.clearSnackBars();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入书源'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '网络导入'),
            Tab(text: '文本导入'),
            Tab(icon: Icon(Icons.code), text: 'JS导入'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildUrlTab(),
              _buildTextTab(),
              _buildJsTab(),
            ],
          ),
          if (_isImporting)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '三步导入：① 复制一个书源 JSON 链接  ② 粘贴到下方  ③ 点「导入」',
            style: TextStyle(color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '书源 JSON 链接',
              hintText: 'https://示例.com/书源.json',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _importFromUrl(),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('记住为订阅源'),
            subtitle: const Text('导入后可在「书源订阅」中一键更新'),
            value: _rememberSubscribe,
            onChanged: _isImporting
                ? null
                : (v) => setState(() => _rememberSubscribe = v),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          FilledButton.icon(
            onPressed: _isImporting ? null : _importFromUrl,
            icon: const Icon(Icons.download),
            label: const Text('导入'),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          OutlinedButton.icon(
            onPressed: _isImporting ? null : _importFromFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('从文件导入'),
          ),
          const SizedBox(height: DesignTokens.spacingLg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('怎么用（看这里）',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: DesignTokens.spacingSm),
                  const Text(
                    '• 支持格式：Legado 书源 JSON（单个对象，或书源数组）\n'
                    '• 链接打开后应直接是 JSON 文本，而不是网页/登录页\n'
                    '• 也支持 {"sourceUrls":["链接1","链接2"]} 订阅格式\n'
                    '• 导入成功会提示：新增几条、更新几条、跳过几条\n'
                    '• 若网络导入失败（尤其是 GitHub 链接），请改用：\n'
                    '    - 「文本导入」：把 JSON 全文粘贴进来\n'
                    '    - 「从文件导入」：选择手机里的 .json 文件\n'
                    '• 重复导入按 bookSourceUrl 去重，不会重复堆很多条',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '粘贴书源 JSON 文本或 JS 书源代码',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: '粘贴书源 JSON 或 JS 代码...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.text_snippet),
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isImporting ? null : _importFromClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('从剪贴板'),
              ),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isImporting ? null : _importFromText,
                  icon: const Icon(Icons.download),
                  label: const Text('导入'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// JS 书源导入标签页
  Widget _buildJsTab() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '粘贴 JS 书源代码，或从文件选择 .js 文件导入',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Expanded(
            child: TextField(
              controller: _jsController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText:
                    '粘贴 JS 书源代码...\n// 示例：\n// {"bookSourceName":"示例","bookSourceUrl":"https://..."}',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isImporting ? null : _importFromJsFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择 .js 文件'),
              ),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isImporting ? null : _importFromJs,
                  icon: const Icon(Icons.code),
                  label: const Text('导入 JS 书源'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingLg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JS 书源说明',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: DesignTokens.spacingSm),
                  const Text(
                    '• JS 书源是使用 JavaScript 语法的书源\n'
                    '• 支持 .js 文件或直接粘贴代码\n'
                    '• 引擎：QuickJS (flutter_js) 或 Rhino (Android)\n'
                    '• 导入后可在书源管理中编辑和调试',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromJs() async {
    final text = _jsController.text.trim();
    if (text.isEmpty) {
      _showError('请输入 JS 书源代码');
      return;
    }
    await _doImport(text);
  }

  Future<void> _importFromJsFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['js'],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isImporting = true);

      final file = result.files.first;
      final bytes = file.bytes ?? await _readFileBytes(file.path!);
      final text = utf8.decode(bytes, allowMalformed: true);

      final importResult = await BookSourceImportService().importJsText(text);
      await _showResultAndPop(importResult);
    } catch (e, st) {
      debugPrint('JS 文件导入失败: $e\n$st');
      _showError(describeSourceImportFailure(e));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}
