import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 通知栏 / 前台服务朗读控制桥接（其他平台为 no-op）。
class ReaderTtsNotificationBridge {
  ReaderTtsNotificationBridge._();

  static final ReaderTtsNotificationBridge instance =
      ReaderTtsNotificationBridge._();

  static const MethodChannel _channel = MethodChannel('com.mr.app/tts');
  static const MethodChannel _callbackChannel =
      MethodChannel('com.mr.app/tts_callback');

  VoidCallback? _onPause;
  VoidCallback? _onResume;
  VoidCallback? _onStop;
  VoidCallback? _onAudioFocusLost;
  VoidCallback? _onAudioFocusGained;
  bool _handlersAttached = false;

  Future<void> attachHandlers({
    required VoidCallback onPause,
    required VoidCallback onResume,
    required VoidCallback onStop,
    VoidCallback? onAudioFocusLost,
    VoidCallback? onAudioFocusGained,
  }) async {
    _onPause = onPause;
    _onResume = onResume;
    _onStop = onStop;
    _onAudioFocusLost = onAudioFocusLost;
    _onAudioFocusGained = onAudioFocusGained;
    if (_handlersAttached) return;
    _handlersAttached = true;
    _callbackChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pause':
          _onPause?.call();
          break;
        case 'resume':
          _onResume?.call();
          break;
        case 'stop':
          _onStop?.call();
          break;
        case 'audioFocusLost':
        case 'audioBecomingNoisy':
          // 来电 / 其他音频 / 耳机拔出：统一走失焦暂停
          (_onAudioFocusLost ?? _onPause)?.call();
          break;
        case 'audioFocusGained':
          _onAudioFocusGained?.call();
          break;
      }
      return null;
    });
  }

  void detachHandlers() {
    _handlersAttached = false;
    _callbackChannel.setMethodCallHandler(null);
    _onPause = null;
    _onResume = null;
    _onStop = null;
    _onAudioFocusLost = null;
    _onAudioFocusGained = null;
  }

  Future<void> show({
    required String title,
    required String body,
    required bool isPaused,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('showTtsNotification', {
        'title': title,
        'body': body.length > 80 ? '${body.substring(0, 80)}…' : body,
        'isPaused': isPaused,
      });
    } on MissingPluginException {
      // 桌面调试无原生实现
    } on PlatformException catch (e) {
      debugPrint('[TTS] notification show failed: ${e.message}');
    }
  }

  Future<void> dismiss() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('dismissTtsNotification');
    } on MissingPluginException {
      // no-op
    } on PlatformException catch (e) {
      debugPrint('[TTS] notification dismiss failed: ${e.message}');
    }
  }
}
