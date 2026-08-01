import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/crash_log_service.dart';

/// `_sessionId` / `_startTime` 曾是只在 init() 里赋值的 late final 字段，
/// 于是 init() 之前的任何一次崩溃记录都会先抛 LateInitializationError，
/// 把真正的错误顶掉——启动期崩溃恰恰最需要日志。
///
/// 这组测试刻意不调用 init()，锁死「未初始化也能用」这个前提。
void main() {
  group('CrashLogService 在 init() 之前', () {
    test('访问 sessionId 不抛异常且非空', () {
      expect(() => CrashLogService.instance.sessionId, returnsNormally);
      expect(CrashLogService.instance.sessionId, isNotEmpty);
    });

    test('sessionId 多次读取保持一致', () {
      final first = CrashLogService.instance.sessionId;
      final second = CrashLogService.instance.sessionId;

      expect(second, first, reason: '惰性求值只应计算一次');
    });

    test('访问 uptimeSeconds 不抛异常', () {
      expect(() => CrashLogService.instance.uptimeSeconds, returnsNormally);
      expect(CrashLogService.instance.uptimeSeconds, greaterThanOrEqualTo(0));
    });
  });
}
