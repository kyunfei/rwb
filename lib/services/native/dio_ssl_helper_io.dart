import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'happy_eyeballs.dart';

/// 非 Web 平台：配置书源 Dio 的原生 [HttpClient]
///
/// 1. **证书**：`badCertificateCallback` 一律放行。书源站点证书常有问题
///    （自签名/过期/链不完整/TLS 版本旧），不绕过会导致 HandshakeException。
/// 2. **双栈连接**：挂上 Happy Eyeballs 风格的 [HttpClient.connectionFactory]，
///    避免「IPv4 黑洞 + IPv6 畅通」时把整段 [BaseOptions.connectTimeout] 耗在
///    不可达的地址族上（Dart 默认 HttpClient 不做 RFC 8305 竞速）。
///
/// 代理：不改动 [HttpClient.findProxy]（仍走环境变量默认逻辑）；
/// `connectionFactory` 收到非空 `proxyHost`/`proxyPort` 时会对**代理本身**做竞速，
/// 与 Dart 文档要求一致。
void configureDioSslBypass(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      final client = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      // 直连 https 的 TLS 在 connectionFactory 内部完成，走不到上面那个回调，
      // 放行策略要单独交给它，否则证书有问题的书源会退回 HandshakeException
      attachHappyEyeballs(client, onBadCertificate: (cert) => true);
      return client;
    };
  }
}
