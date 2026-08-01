import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../pages/reader/reader_text_cleaner.dart';
import 'reader_tts_notification_bridge.dart';

/// 朗读用分句结果。
class ReaderTtsSegment {
  final int index;
  final String text;
  final int startOffset;
  final int endOffset;

  const ReaderTtsSegment({
    required this.index,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });
}

/// 章节读完回调：返回 true 表示已成功加载并切换到下一章内容。
typedef ReaderTtsChapterCompleteCallback = Future<bool> Function();

/// 当前句变化（用于 WebView 高亮与翻页跟随）。
typedef ReaderTtsSegmentCallback = void Function(ReaderTtsSegment segment);

/// 阅读器 TTS 引擎（按需初始化，不阻塞 App 冷启动）。
class ReaderTtsService {
  ReaderTtsService();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _pausedByFocusLoss = false;
  int _segmentIndex = 0;
  double _rate = 0.5;
  double _pitch = 1.0;
  String? _voiceName;
  Timer? _sleepTimer;

  List<ReaderTtsSegment> _segments = const [];

  VoidCallback? _onStateChanged;
  ReaderTtsSegmentCallback? _onSegmentChanged;
  ReaderTtsChapterCompleteCallback? _onChapterComplete;

  bool get isInitialized => _initialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  int get segmentIndex => _segmentIndex;
  int get segmentCount => _segments.length;
  double get rate => _rate;
  double get pitch => _pitch;
  String? get voiceName => _voiceName;

  ReaderTtsSegment? get currentSegment {
    if (_segmentIndex < 0 || _segmentIndex >= _segments.length) return null;
    return _segments[_segmentIndex];
  }

  /// 首次朗读时调用；重复调用无副作用。
  Future<void> ensureInitialized({
    double rate = 0.5,
    VoidCallback? onStateChanged,
    ReaderTtsSegmentCallback? onSegmentChanged,
    ReaderTtsChapterCompleteCallback? onChapterComplete,
  }) async {
    _onStateChanged = onStateChanged;
    _onSegmentChanged = onSegmentChanged;
    _onChapterComplete = onChapterComplete;
    _rate = rate;
    if (_initialized) return;

    try {
      await ReaderTtsNotificationBridge.instance.attachHandlers(
        onPause: pause,
        onResume: () => unawaited(resume()),
        onStop: stop,
      );

      for (final code in ['zh-CN', 'zh', 'cmn', 'zh-Hans']) {
        final ok = await _tts.setLanguage(code);
        if (ok == 1) break;
      }

      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);
      if (_voiceName != null && _voiceName!.isNotEmpty) {
        await _tts.setVoice(<String, String>{
          'name': _voiceName!,
          'locale': 'zh-CN',
        });
      }

      _tts.setCompletionHandler(_onUtteranceComplete);
      _tts.setErrorHandler((msg) {
        debugPrint('[TTS] error: $msg');
        if (_isSpeaking && !_isPaused) {
          unawaited(_advanceSegment());
        }
      });
      _tts.setPauseHandler(() {
        _isPaused = true;
        _notifyState();
      });
      _tts.setContinueHandler(() {
        _isPaused = false;
        _notifyState();
      });

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _tts.awaitSpeakCompletion(true);
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('[TTS] ensureInitialized failed: $e\n$st');
    }
  }

  void setChapterPlainText(String cleanedPlainText, {int startOffset = 0}) {
    _segments = _splitSegments(cleanedPlainText);
    _segmentIndex = segmentIndexForOffset(startOffset);
    _notifySegment();
  }

  Future<void> start({int? fromSegmentIndex}) async {
    if (!_initialized) return;
    if (fromSegmentIndex != null) {
      _segmentIndex = fromSegmentIndex.clamp(0, _segments.length);
    }
    _isSpeaking = true;
    _isPaused = false;
    _pausedByFocusLoss = false;
    await _enableKeepAwake(true);
    _notifyState();
    await _tts.stop();
    await _speakCurrent();
    await _syncNotification();
  }

  void pause() {
    if (!_isSpeaking || _isPaused) return;
    _isPaused = true;
    _tts.pause();
    _notifyState();
    unawaited(_syncNotification());
  }

  Future<void> resume() async {
    if (!_isSpeaking) {
      await start();
      return;
    }
    if (!_isPaused) return;
    _isPaused = false;
    _pausedByFocusLoss = false;
    _notifyState();
    await _speakCurrent();
    await _syncNotification();
  }

  void stop() {
    _cancelSleepTimer();
    _isSpeaking = false;
    _isPaused = false;
    _pausedByFocusLoss = false;
    unawaited(_tts.stop());
    unawaited(_enableKeepAwake(false));
    unawaited(ReaderTtsNotificationBridge.instance.dismiss());
    _notifyState();
  }

  Future<void> nextSegment() async {
    if (_segmentIndex < _segments.length - 1) {
      _segmentIndex++;
      _notifySegment();
      await _tts.stop();
      if (_isSpeaking && !_isPaused) {
        await _speakCurrent();
      }
    } else {
      await _onChapterFinished();
    }
  }

  Future<void> prevSegment() async {
    if (_segmentIndex > 0) {
      _segmentIndex--;
      _notifySegment();
      await _tts.stop();
      if (_isSpeaking && !_isPaused) {
        await _speakCurrent();
      }
    }
  }

  Future<void> goToSegment(int index) async {
    if (index < 0 || index >= _segments.length) return;
    _segmentIndex = index;
    _notifySegment();
    await _tts.stop();
    if (_isSpeaking && !_isPaused) {
      await _speakCurrent();
    }
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.1, 2.0);
    if (_initialized) {
      await _tts.setSpeechRate(_rate);
    }
    _notifyState();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_initialized) {
      await _tts.setPitch(_pitch);
    }
    _notifyState();
  }

  Future<void> setVoice(String? name) async {
    _voiceName = name;
    if (_initialized && name != null && name.isNotEmpty) {
      await _tts.setVoice(<String, String>{'name': name, 'locale': 'zh-CN'});
    }
    _notifyState();
  }

  Future<List<Map<String, String>>> listVoices() async {
    if (!_initialized) {
      await ensureInitialized();
    }
    try {
      final dynamic raw = await _tts.getVoices;
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString())))
            .where((m) {
          final locale = m['locale'] ?? '';
          return locale.startsWith('zh');
        }).toList();
      }
    } catch (e) {
      debugPrint('[TTS] listVoices failed: $e');
    }
    return const [];
  }

  /// 定时关闭（分钟）；0 表示取消。
  void setSleepTimerMinutes(int minutes) {
    _cancelSleepTimer();
    if (minutes <= 0) return;
    _sleepTimer = Timer(Duration(minutes: minutes), stop);
  }

  void pauseForAudioFocusLoss() {
    if (!_isSpeaking || _isPaused) return;
    _pausedByFocusLoss = true;
    pause();
  }

  Future<void> resumeAfterAudioFocusGain() async {
    if (!_pausedByFocusLoss) return;
    _pausedByFocusLoss = false;
    await resume();
  }

  void dispose() {
    _cancelSleepTimer();
    stop();
    ReaderTtsNotificationBridge.instance.detachHandlers();
    try {
      _tts.setCompletionHandler(() {});
    } catch (_) {}
    _initialized = false;
  }

  void _onUtteranceComplete() {
    if (!_isSpeaking || _isPaused) return;
    unawaited(_advanceSegment());
  }

  Future<void> _advanceSegment() async {
    if (_segmentIndex < _segments.length - 1) {
      _segmentIndex++;
      _notifySegment();
      await _speakCurrent();
    } else {
      await _onChapterFinished();
    }
  }

  Future<void> _onChapterFinished() async {
    final handler = _onChapterComplete;
    if (handler == null) {
      stop();
      return;
    }
    final loaded = await handler();
    if (!loaded || _segments.isEmpty) {
      stop();
      return;
    }
    _segmentIndex = 0;
    _notifySegment();
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (!_isSpeaking || _isPaused) return;
    if (_segmentIndex >= _segments.length) {
      await _onChapterFinished();
      return;
    }
    final text = _segments[_segmentIndex].text;
    if (text.isEmpty) {
      await _advanceSegment();
      return;
    }
    await _syncNotification();
    await _tts.speak(text);
  }

  Future<void> _syncNotification() async {
    if (!_isSpeaking) return;
    final seg = currentSegment;
    await ReaderTtsNotificationBridge.instance.show(
      title: '朗读中',
      body: seg?.text ?? '',
      isPaused: _isPaused,
    );
  }

  Future<void> _enableKeepAwake(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('[TTS] wakelock: $e');
    }
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  void _notifyState() {
    _onStateChanged?.call();
  }

  void _notifySegment() {
    final seg = currentSegment;
    if (seg != null) {
      _onSegmentChanged?.call(seg);
    }
    _onStateChanged?.call();
  }

  static List<ReaderTtsSegment> _splitSegments(String cleaned) {
    if (cleaned.isEmpty) return const [];

    final pattern = RegExp(r'[^。！？；!?;…\n]+[。！？；!?;…]?');
    final matches = pattern.allMatches(cleaned);
    final segments = <ReaderTtsSegment>[];
    var idx = 0;
    for (final m in matches) {
      final slice = cleaned.substring(m.start, m.end).trim();
      if (slice.isEmpty) continue;
      segments.add(
        ReaderTtsSegment(
          index: idx,
          text: slice,
          startOffset: m.start,
          endOffset: m.end,
        ),
      );
      idx++;
    }
    if (segments.isEmpty) {
      segments.add(
        ReaderTtsSegment(
          index: 0,
          text: cleaned,
          startOffset: 0,
          endOffset: cleaned.length,
        ),
      );
    }
    return segments;
  }

  int segmentIndexForOffset(int offset) {
    if (_segments.isEmpty) return 0;
    for (var i = 0; i < _segments.length; i++) {
      if (offset < _segments[i].endOffset) return i;
    }
    return _segments.length - 1;
  }

  /// 从原始章节正文生成朗读用纯文本。
  static String cleanPlainText(String rawChapterText) {
    return ReaderTextCleaner.cleanForTts(rawChapterText);
  }
}
