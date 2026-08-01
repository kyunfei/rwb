import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr/services/native/happy_eyeballs.dart';

void main() {
  final v4 = InternetAddress('1.2.3.4');
  final v6 = InternetAddress('2001:db8::1');
  final v4b = InternetAddress('5.6.7.8');
  final v6b = InternetAddress('2001:db8::2');

  group('interleaveAddressFamilies', () {
    test('双栈交错且 IPv6 领跑', () {
      expect(
        interleaveAddressFamilies([v4, v4b, v6, v6b]),
        [v6, v4, v6b, v4b],
      );
    });

    test('仅 IPv4 / 仅 IPv6 保持原序子集', () {
      expect(interleaveAddressFamilies([v4, v4b]), [v4, v4b]);
      expect(interleaveAddressFamilies([v6, v6b]), [v6, v6b]);
    });

    test('空列表', () {
      expect(interleaveAddressFamilies(const []), isEmpty);
    });
  });

  group('resolveConnectTarget', () {
    test('无代理时用 URL 主机与默认端口', () {
      final t = resolveConnectTarget(
        Uri.parse('https://zh.wikisource.org/wiki/X'),
        null,
        null,
      );
      expect(t.host, 'zh.wikisource.org');
      expect(t.port, 443);
    });

    test('有代理时连代理而非源站', () {
      final t = resolveConnectTarget(
        Uri.parse('https://zh.wikisource.org/wiki/X'),
        '127.0.0.1',
        7890,
      );
      expect(t.host, '127.0.0.1');
      expect(t.port, 7890);
    });
  });

  group('raceConnectAttempts', () {
    test('挂死的地址不会拖累快速成功的地址', () async {
      final cancelled = <String>[];
      final sw = Stopwatch()..start();

      final winner = await raceConnectAttempts<String>(
        addresses: [v4, v6],
        port: 443,
        stagger: Duration.zero,
        startConnect: (address, port) async {
          if (address.type == InternetAddressType.IPv4) {
            // 模拟 IPv4 黑洞：connect 永不返回
            final never = Completer<String>();
            return ConnectAttempt<String>(
              socket: never.future,
              cancel: () => cancelled.add(address.address),
            );
          }
          return ConnectAttempt<String>(
            socket: Future<String>.delayed(
              const Duration(milliseconds: 30),
              () => 'ok-v6',
            ),
            cancel: () => cancelled.add(address.address),
          );
        },
      );

      sw.stop();
      expect(winner, 'ok-v6');
      // 远小于 Dio 默认 15s connectTimeout；给 CI 抖动留余量
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(cancelled, contains(v4.address));
    });

    test('IPv6 领跑间隔内已胜出则不再启动后续地址', () async {
      final started = <String>[];

      final winner = await raceConnectAttempts<String>(
        addresses: [v6, v4],
        port: 443,
        stagger: const Duration(milliseconds: 200),
        startConnect: (address, port) async {
          started.add(address.address);
          return ConnectAttempt<String>(
            socket: Future<String>.value('fast-${address.address}'),
            cancel: () {},
          );
        },
      );

      expect(winner, 'fast-${v6.address}');
      expect(started, [v6.address]);
      expect(started, isNot(contains(v4.address)));
    });

    test('胜出后关掉其余：迟到成功的连接走 discard', () async {
      final cancelled = <String>[];
      final discarded = <String>[];
      final slowDone = Completer<void>();

      final winner = await raceConnectAttempts<String>(
        addresses: [v4, v6],
        port: 443,
        stagger: Duration.zero,
        discard: discarded.add,
        startConnect: (address, port) async {
          if (address.type == InternetAddressType.IPv4) {
            return ConnectAttempt<String>(
              socket: Future<String>.delayed(
                const Duration(milliseconds: 80),
                () {
                  slowDone.complete();
                  return 'late-v4';
                },
              ),
              cancel: () => cancelled.add(address.address),
            );
          }
          return ConnectAttempt<String>(
            socket: Future<String>.delayed(
              const Duration(milliseconds: 10),
              () => 'win-v6',
            ),
            cancel: () => cancelled.add(address.address),
          );
        },
      );

      expect(winner, 'win-v6');
      expect(cancelled, contains(v4.address));
      await slowDone.future.timeout(const Duration(seconds: 2));
      // cancel 之后假 socket 仍可能完成；编排必须 discard，不能当第二胜者
      expect(discarded, contains('late-v4'));
    });

    test('全部失败时抛出 SocketException', () async {
      await expectLater(
        raceConnectAttempts<String>(
          addresses: [v4, v6],
          port: 443,
          stagger: Duration.zero,
          startConnect: (address, port) async {
            return ConnectAttempt<String>(
              // 用 delayed throw，避免 Future.error 在监听前被标成未处理异常
              socket: Future<String>.delayed(
                Duration.zero,
                () => throw SocketException('refused ${address.address}'),
              ),
              cancel: () {},
            );
          },
        ),
        throwsA(
          isA<SocketException>().having(
            (e) => e.message,
            'message',
            contains('All connection attempts failed'),
          ),
        ),
      );
    });

    test('空地址列表立即失败', () async {
      await expectLater(
        raceConnectAttempts<String>(
          addresses: const [],
          port: 443,
          startConnect: (address, port) async {
            fail('不应启动连接');
          },
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('happyEyeballsConnectionTask', () {
    test('ConnectionTask.cancel 会中止竞速并让 socket Future 失败', () async {
      final cancelled = <String>[];
      final task = await happyEyeballsConnectionTask(
        Uri.parse('https://example.test/'),
        null,
        null,
        stagger: Duration.zero,
        lookup: (host) async {
          expect(host, 'example.test');
          return [v4, v6];
        },
        startConnect: (address, port) async {
          final c = Completer<Socket>();
          return ConnectAttempt<Socket>(
            socket: c.future,
            cancel: () {
              cancelled.add(address.address);
              if (!c.isCompleted) {
                c.completeError(
                  const SocketException('Connection attempt cancelled'),
                );
              }
            },
          );
        },
      );

      // 等两族都启动
      await Future<void>.delayed(const Duration(milliseconds: 20));
      task.cancel();
      expect(cancelled, containsAll([v4.address, v6.address]));
      await expectLater(task.socket, throwsA(isA<SocketException>()));
    });

    test('有代理时 lookup 的是代理主机', () async {
      String? lookedUp;
      int? connectedPort;
      final task = await happyEyeballsConnectionTask(
        Uri.parse('https://zh.wikisource.org/'),
        '10.0.0.1',
        8080,
        stagger: Duration.zero,
        lookup: (host) async {
          lookedUp = host;
          return [InternetAddress('10.0.0.1')];
        },
        startConnect: (address, port) async {
          connectedPort = port;
          return ConnectAttempt<Socket>(
            socket: Future<Socket>.delayed(
              Duration.zero,
              () => throw const SocketException('stop'),
            ),
            cancel: () {},
          );
        },
      );

      expect(lookedUp, '10.0.0.1');
      expect(connectedPort, 8080);
      await expectLater(task.socket, throwsA(isA<SocketException>()));
    });
  });
}
