# MR — 多媒体阅读器（Flutter）

> 本文档为 AI 协作代理（agentic coding）提供的项目工作约定，与 `README.md` 互补。
> 内容根据当前代码库真实状态编写，用于指导 AI 代理在本仓库工作时的命令、测试、架构与约定。

## 命令

```bash
flutter pub get          # 安装依赖
flutter run              # 在连接的设备/模拟器上运行
flutter build apk        # 构建 Android APK（触发 QuickJS C 桥接 CMake 编译）
flutter build ios        # 构建 iOS（需 macOS + Xcode）
flutter build hap        # 构建 HarmonyOS HAP（需鸿蒙 Flutter SDK）
flutter test             # 运行 test/ 下全部测试
flutter analyze          # lint + 静态分析
```

> 项目根的 `flutter.bat` / `flutter.ps1` 已预设国内镜像并指向 `D:\flutter_windows_3.44.8-stable`，可设 `FLUTTER_ROOT` 覆盖。
> 需 Flutter 3.44.8（Dart 3.12.2）以上：`pubspec.yaml` 要求 `sdk: '>=3.12.0'`，3.41.x 自带的 Dart 3.11.5 会导致 `pub get` 失败。
> 若 `C:` 盘空间不足，可设 `$env:TEMP` 指向项目下临时目录再运行 `flutter test`。

### 临时文件约定

日志、analyze 输出、构建脚本等中间产物**一律写到 `$env:TEMP` 下**，不要落在仓库里，更不要落在仓库的父目录（`D:\WorkSpace`）——那里还并列着其他项目。任务结束前自行清理。

APK 体积只以 **release 包**为准：debug 包的文件大小受 zip 对齐填充影响，会在 84 MiB 和 117 MiB 之间无规律摆动，而包内条目完全相同，据此比较体积会得出错误结论。

## 测试

`test/` 下 17 个测试文件。当前基准：**97 通过 / 7 失败**，失败项全部来自 `crypto_native_test.dart`（下表已注明原因），其余必须全绿。

| 文件 | 内容 | 备注 |
|------|------|------|
| `widget_test.dart` | 占位，恒通过 | — |
| `legado_rule_test.dart` | CSS/JSoup 链式选择器规则、索引与区间 | 反向区间（`[-1:0]`、`4:0:-1`）必须保持倒序，勿在 `apply()` 里对下标排序 |
| `book_source_compat_test.dart` | 书源导入、URL 解析、元数据合并、源定位 | — |
| `crypto_native_test.dart` | C 原生加密对比 | **7 例必然失败**：需加载 `quickjs_c_bridge.dll` / `libquickjs_c_bridge.so`，桌面测试运行器没有该库 |
| `chinese_converter_test.dart` | 简繁中文转换 | — |
| `charset_utils_test.dart` | GBK/GB18030/EUC-JP 等编码解码与嗅探 | — |
| `big5_charset_decode_test.dart` | Big5/CP950 解码 | — |
| `big5_cp950_crosscheck_test.dart` | Big5 表正确性交叉验证 | 字节与期望串由 Windows CP950 机器导出，改映射表后必须仍全绿 |
| `crash_log_session_test.dart` | `init()` 之前访问日志服务不得抛异常 | — |
| `reader_pagination_utils_test.dart` / `reader_text_cleaner_test.dart` | 阅读器分页与正文清洗 | — |
| `search_normalize_rank_test.dart` | 多源搜索归一化与排序 | — |
| `shelf_chapter_diff_test.dart` / `shelf_download_queue_state_machine_test.dart` | 书架更新检测、下载队列状态机 | — |
| `source_health_logic_test.dart` / `source_import_logic_test.dart` / `source_rule_step_logic_test.dart` | 书源健康检查、导入、规则分步调试 | — |

```bash
flutter test test/legado_rule_test.dart
flutter test test/book_source_compat_test.dart
```

CI 只跑 `flutter analyze` 门禁，不跑测试；测试需本地运行。

## 架构

| 层 | 技术 |
|----|------|
| 状态管理 | Provider（`lib/providers/` 6 个：App / Bookshelf / Discovery / ExploreShow / Reader / Search） |
| 存储 | Hive（`main.dart` 初始化 `Hive.initFlutter()` → `StorageService.init()`） |
| HTTP | Dio（Web 走 `ProxyService` 启动的 CORS 代理） |
| JS | QuickJS（`flutter_js` + FFI，单引擎调度） |
| 路由 | 自定义 `AppPageRoute` + `PageRouteBuilder`，零时长切换，定义于 `lib/routes/app_routes.dart` |
| 图片解密 | `DecodedImageProvider`（自定义 ImageProvider，下载→JS 解密→解码） |
| 崩溃日志 | `CrashLogService`（启动最先初始化，注册全局错误捕获） |

### 入口初始化顺序

`lib/main.dart` — 在 `runZonedGuarded` 中依次：

1. `CrashLogService.instance.init()` — 崩溃日志（最先，注册全局错误捕获）
2. `AppLogger.instance.initFileLogging()` + `enableDebugPrintCapture()` — 应用日志
3. `Hive.initFlutter()` → `StorageService.instance.init()` — 本地存储
4. `JsEngine.instance.init()` — JS 引擎
5. `CoverConfigService.instance.init()` — 封面配置
6. `ProxyService.instance.start()` — CORS 代理（仅 Web）
7. `runApp(DanShenqiApp())`

> 每个服务初始化均包裹在 try-catch 中，单个服务失败不中断启动。
> `StorageService` 未初始化时，所有同步 getter（`getAllBooks`/`getBook` 等）返回空值，避免 `HiveError` 崩溃。

### 关键目录

```
lib/
  services/source_engine/   # Legado 规则引擎核心（analyze_rule / web_book / legado_json_path / legado_xpath / proxy_service）
  services/native/          # JS 引擎调度、QuickJS FFI 绑定、平台通道、Dio SSL
  services/local_book/      # 本地书解析（EPUB / TXT）
  services/                  # storage_service / book_data_provider / chapter_cache_service / image_decode_provider / crash_log_service / app_logger 等
  models/                   # BookSource / Book / Chapter / Highlight / Miniprogram / ReplaceRule 及 rules/ 六类子模型
  pages/                    # 12 个子目录：bookshelf / reader(comic+novel) / debug / detail / search / discovery / explore / miniprogram / web / profile(11 子页) / settings(含 theme/ 16 个模块) / main
  providers/                # App / Bookshelf / Discovery / Reader / Search / ExploreShow
  routes/
  utils/                    # design_tokens / chinese_converter / share_helper
  widgets/                  # 公共组件 + reader/ 子组件
  themes/                   # theme_config + ui_corner
```

## Web 平台

`kIsWeb` 时由 `main.dart` 中 `ProxyService.instance.start()` 自动启动 CORS 代理。工具脚本：`tools/cors-proxy.js`。

## 原生 C 桥接

- 源码：`quickjs/`（含 `crypto/`、`lexbor/` 等子目录）
- 编译产物：`libquickjs_c_bridge.so`（Android）/ `quickjs_c_bridge.dll`（Windows）
- 构建脚本：`android/app/src/main/cpp/CMakeLists.txt` + `quickjs_bridge.map`
- 鸿蒙构建：`quickjs/ohos/CMakeLists.txt`（CI 注入 `ohos/entry/src/main/cpp/`）
- 入口绑定：`lib/services/native/quickjs_runtime.dart`（FFI）+ `quickjs_runtime_stub.dart`（Web 桩）

## 图片解密

`lib/services/image_decode_provider.dart` — `DecodedImageProvider`：

- `needsDecode(source, isCover)` 判断书源是否配置了 `coverDecodeJs`（封面）或 `ruleContent.imageDecode`（正文）
- 需要解密时走 `DecodedImageProvider`（下载→JS 解密→解码），否则走 `CachedNetworkImage`（享受磁盘缓存）
- 已重写 `==` 和 `hashCode`（基于 url + isCover），Flutter `ImageCache` 可正常复用

使用位置：`bookshelf_page` / `search_page` / `detail_page` / `read_record_page` / `bookmark_page` / `storage_manage_page` / `comic_reader_page`。

## 漫画阅读器缓存策略

`lib/pages/reader/comic_reader_page.dart`：

- **纯按需加载**：翻页时只加载当前页，不预缓存下一张
- **缓存按钮**：`_downloadCurrentChapter` 只缓存当前一张，`_isDownloading` 防重入，`_precachedUrls` Set 去重
- **base64 解码缓存**：`_dataImageCache` Map 避免重复解析
- **日志去重**：`_loggedImageUrls`（开始加载）和 `_loggedErrorUrls`（加载失败）独立 Set，O(1) 查找

## 静态分析

`analysis_options.yaml` **已入库**（早先被 `.gitignore` 忽略，等于全项目没有 lint，已修正）。现以 `include: package:flutter_lints/flutter.yaml` 为基础，另开 `unawaited_futures` 与 `always_declare_return_types`。

由 `avoid_print` 强制：使用 `debugPrint` 替代 `print`。

当前 `flutter analyze --no-fatal-infos` 为 **19 项 info、0 error、0 warning**；CI 门禁上限 30，只许降不许升。

## 持续集成

### `.github/workflows/main.yml` — 自动合并

push 到任意分支（非 master）时，自动将该分支合并到 master。冲突 → 自动创建 PR。

### `.github/workflows/build.yml` — 多平台构建发布

| 平台 | 触发 | 产物 | 签名 |
|------|------|------|------|
| Android | push master / 手动 | `mr_v*_dev_*.apk`（arm64） | Release 签名 |
| iOS | push master / 手动 | `mr_v*_dev_*.ipa` | 未签名（`--no-codesign`） |
| HarmonyOS | push master / 手动 | `mr_v*_dev_*.hap` | 未签名（用户自行用 DevEco Studio 签名） |

- 版本号格式：`YY.MMDD.今日提交数`（如 `25.0715.3`）
- 鸿蒙 Flutter SDK 为华为 fork（`gitcode.com/openharmony-sig/flutter_flutter`），CI 动态获取最新 release 分支
- iOS / HarmonyOS 构建允许失败（`continue-on-error: true`），不阻塞发布

### lint 门禁

`build.yml` 的 `analyze` job 在 **push 与 pull_request 上都跑**（早先只在 push master 跑，分支和 PR 根本不过门禁）。`ANALYZE_BASELINE` 为上限，超出即失败。PR 上只跑该 job，构建与发布 job 跳过。

CI 不跑测试。

## 约定

- 全项目使用中文注释与中文标识符
- 路由参数使用 `Map<String, dynamic>?`（见 `app_routes.dart` 模式）
- 路由参数可能是 `Map`（动态）或 `Map<String, dynamic>` — 代码通过 `is Map` 检查兼容两种
- 通过 `Book.fromJson` / `BookSource.fromJson` 进行序列化
- 删除文件时同步清理 barrel export（`source_engine.dart` 等）
- 异步操作后使用 `BuildContext` 前必须检查 `mounted`；在 `showDialog` 的 builder 里，要在 `Navigator.pop()` 与任何 `await` **之前**先取好 `ScaffoldMessenger` 等依赖 context 的对象，且勿用 `context` 命名 builder 参数以免遮蔽外层
- 空值断言 `!` 应替换为局部变量 + null 检查（类型提升）
- 改 `android/` 下的 Kotlin 代码后必须真正构建一次 APK：`flutter analyze` 与 `flutter test` 都不编译 Kotlin，写错 `final`/`val` 这类问题只有构建才会暴露

### 不要"顺手清理"的东西

- **`MediaType.video` / `MediaType.audio`、`BookSourceType.audio` / `video`**：音视频播放页已删除，这几个枚举值看似无用，但 `Book.fromJson` 按 `MediaType.values[index]` 反序列化，删掉会让已有书架的旧数据错位。书架的音频/视频分组过滤同理保留，只是不再有播放页，打开时提示不支持。
- **`lib/services/source_engine/big5_table.dart`**：生成文件，由 `tools/gen_big5_table.ps1` 从 Windows CP950 码页导出，勿手改；改动后跑 `big5_cp950_crosscheck_test.dart` 验证。
- **编码解析链**：`web_book.dart` 一律以 `ResponseType.bytes` 取响应，再按「书源声明 > Content-Type 头 > HTML meta 嗅探 > UTF-8」的优先级解码；meta 嗅探只看开头 2KB 且用 latin-1 逐字节还原，勿改成"先按某编码解全文再找 charset"。
