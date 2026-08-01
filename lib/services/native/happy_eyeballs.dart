import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 一次可取消的连接尝试（抽象自 [ConnectionTask]，便于单测注入假实现）。
class ConnectAttempt<T> {
  ConnectAttempt({
    required this.socket,
    required this.cancel,
  });

  /// 完成时交出已建立的连接（测试里可以是任意对象）。
  final Future<T> socket;

  /// 中止本次尝试；胜出后应对其余尝试调用。
  final void Function() cancel;
}

/// 启动一次连接。生产环境对接 [Socket.startConnect]，测试注入假实现。
typedef StartConnect<T> = Future<ConnectAttempt<T>> Function(
  InternetAddress address,
  int port,
);

/// 将 DNS 结果按 Happy Eyeballs 习惯交错：v6[0], v4[0], v6[1], v4[1]…
///
/// 保证双栈时优先尝试 IPv6，又不会把全部 IPv4 排到所有 IPv6 之后。
List<InternetAddress> interleaveAddressFamilies(List<InternetAddress> addresses) {
  final v6 = <InternetAddress>[];
  final v4 = <InternetAddress>[];
  for (final a in addresses) {
    if (a.type == InternetAddressType.IPv6) {
      v6.add(a);
    } else if (a.type == InternetAddressType.IPv4) {
      v4.add(a);
    }
  }
  if (v6.isEmpty) return v4;
  if (v4.isEmpty) return v6;

  final out = <InternetAddress>[];
  final n = math.max(v6.length, v4.length);
  for (var i = 0; i < n; i++) {
    if (i < v6.length) out.add(v6[i]);
    if (i < v4.length) out.add(v4[i]);
  }
  return out;
}

/// 双栈并行竞速编排（Happy Eyeballs 风格）。
///
/// ## 相对完整 RFC 8305 的取舍
/// - **DNS**：调用方先解析再传入地址列表。这里不做「边解析边连接」；
///   完整 HE 会在 AAAA 先回来时立刻开连，不必等 A。
/// - **间隔**：相邻两次 `startConnect` 默认错开 [stagger]（250ms），
///   相当于给列表中靠前的地址（通常是 IPv6）小幅领跑，而不是完全同时狂发。
/// - **地址排序**：只用族交错，不做完整 RFC 6724 目的地址排序。
/// - **黑洞丢包**：这是相对「缩短单次超时再串行换族」的关键收益——
///   IPv4 黑洞时 connect 不会快速失败，串行短超时仍要等满超时；
///   竞速下另一族成功即可胜出，并 [ConnectAttempt.cancel] 挂死的那一侧。
///
/// [discard]：迟到的成功连接必须释放（真 Socket 上调用 destroy），避免泄漏。
Future<T> raceConnectAttempts<T>({
  required List<InternetAddress> addresses,
  required int port,
  required StartConnect<T> startConnect,
  Duration stagger = const Duration(milliseconds: 250),
  void Function(T value)? discard,
}) async {
  if (addresses.isEmpty) {
    throw const SocketException('No addresses available for connection');
  }

  final completer = Completer<T>();
  final pending = <ConnectAttempt<T>>[];
  final errors = <Object>[];
  var launched = 0;
  var settled = 0;
  var finishedLaunching = false;

  void tryCompleteError() {
    if (completer.isCompleted) return;
    if (!finishedLaunching) return;
    if (settled < launched) return;
    final detail = errors.isEmpty
        ? 'unknown'
        : errors.map((e) => e.toString()).join('; ');
    completer.completeError(
      SocketException('All connection attempts failed: $detail'),
    );
  }

  void cancelOthers(ConnectAttempt<T>? winner) {
    for (final attempt in pending) {
      if (identical(attempt, winner)) continue;
      try {
        attempt.cancel();
      } catch (_) {}
    }
  }

  void onAttemptSettled() {
    settled++;
    tryCompleteError();
  }

  Future<void> launch(InternetAddress address) async {
    if (completer.isCompleted) return;
    launched++;
    late final ConnectAttempt<T> attempt;
    try {
      attempt = await startConnect(address, port);
    } catch (e) {
      errors.add(e);
      onAttemptSettled();
      return;
    }
    if (completer.isCompleted) {
      try {
        attempt.cancel();
      } catch (_) {}
      onAttemptSettled();
      return;
    }
    pending.add(attempt);

    try {
      final value = await attempt.socket;
      if (!completer.isCompleted) {
        cancelOthers(attempt);
        completer.complete(value);
      } else {
        discard?.call(value);
        try {
          attempt.cancel();
        } catch (_) {}
      }
    } catch (e) {
      errors.add(e);
    } finally {
      onAttemptSettled();
    }
  }

  for (var i = 0; i < addresses.length; i++) {
    if (completer.isCompleted) break;
    if (i > 0 && stagger > Duration.zero) {
      await Future<void>.delayed(stagger);
      if (completer.isCompleted) break;
    }
    // 并行：不等待单次连接结束，只错开启动时刻
    unawaited(launch(addresses[i]));
  }
  finishedLaunching = true;
  tryCompleteError();

  return completer.future;
}

/// 解析连接目标主机：有代理则连代理，否则连 URL 主机。
({String host, int port}) resolveConnectTarget(
  Uri url,
  String? proxyHost,
  int? proxyPort,
) {
  if (proxyHost != null && proxyHost.isNotEmpty) {
    return (host: proxyHost, port: proxyPort ?? _defaultPortFor(url));
  }
  final port = url.hasPort ? url.port : _defaultPortFor(url);
  return (host: url.host, port: port);
}

int _defaultPortFor(Uri url) {
  if (url.scheme == 'https') return 443;
  if (url.scheme == 'http') return 80;
  return url.port;
}

/// 供 [HttpClient.connectionFactory] 使用的双栈竞速连接。
///
/// 先完成 DNS，再返回 [ConnectionTask]；HttpClient 取消时会中止尚未胜出的尝试。
/// 保留对 [proxyHost]/[proxyPort] 的尊重——有代理时竞速的是代理地址，而非源站。
Future<ConnectionTask<Socket>> happyEyeballsConnectionTask(
  Uri url,
  String? proxyHost,
  int? proxyPort, {
  StartConnect<Socket>? startConnect,
  Future<List<InternetAddress>> Function(String host)? lookup,
  Duration stagger = const Duration(milliseconds: 250),
}) async {
  final target = resolveConnectTarget(url, proxyHost, proxyPort);
  final lookupFn = lookup ?? InternetAddress.lookup;
  final resolved = await lookupFn(target.host);
  final ordered = interleaveAddressFamilies(resolved);
  if (ordered.isEmpty) {
    throw SocketException('Failed host lookup: ${target.host}');
  }

  final start = startConnect ?? _defaultStartConnect;
  final tracked = <ConnectAttempt<Socket>>[];
  final result = Completer<Socket>();
  var cancelled = false;

  void cancelAll() {
    cancelled = true;
    for (final attempt in tracked) {
      try {
        attempt.cancel();
      } catch (_) {}
    }
    if (!result.isCompleted) {
      result.completeError(
        const SocketException('Connection attempt cancelled'),
      );
    }
  }

  Future<ConnectAttempt<Socket>> trackingStart(
    InternetAddress address,
    int port,
  ) async {
    if (cancelled) {
      throw const SocketException('Connection attempt cancelled');
    }
    final attempt = await start(address, port);
    tracked.add(attempt);
    if (cancelled) {
      try {
        attempt.cancel();
      } catch (_) {}
    }
    return attempt;
  }

  unawaited(
    raceConnectAttempts<Socket>(
      addresses: ordered,
      port: target.port,
      startConnect: trackingStart,
      stagger: stagger,
      discard: (socket) {
        try {
          socket.destroy();
        } catch (_) {}
      },
    ).then((socket) {
      if (result.isCompleted) {
        try {
          socket.destroy();
        } catch (_) {}
        return;
      }
      try {
        final remote = socket.remoteAddress;
        final family =
            remote.type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4';
        debugPrint(
          '🌐 HappyEyeballs: ${target.host}:${target.port} '
          'via $family ${remote.address}',
        );
      } catch (_) {
        debugPrint('🌐 HappyEyeballs: ${target.host}:${target.port} connected');
      }
      result.complete(socket);
    }, onError: (Object e, StackTrace st) {
      if (!result.isCompleted) {
        result.completeError(e, st);
      }
    }),
  );

  return ConnectionTask.fromSocket(result.future, cancelAll);
}

StartConnect<Socket> get _defaultStartConnect => (address, port) async {
  final task = await Socket.startConnect(address, port);
  return ConnectAttempt<Socket>(
    socket: task.socket,
    cancel: task.cancel,
  );
};

/// 给已有 [HttpClient] 挂上 Happy Eyeballs 风格的 [HttpClient.connectionFactory]。
void attachHappyEyeballs(HttpClient client) {
  client.connectionFactory = happyEyeballsConnectionTask;
}
