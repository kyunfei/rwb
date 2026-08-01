import 'package:flutter/foundation.dart';

import '../pages/reader/reader_text_cleaner.dart';
import 'reader_tts_service.dart';

/// 阅读器 TTS 管理器（委托 [ReaderTtsService]，保留 Provider 侧 API）。
class ReaderTtsManager {
  ReaderTtsManager();

  final ReaderTtsService _service = ReaderTtsService();

  VoidCallback? _onStateChanged;
  VoidCallback? _onParagraphChanged;
  ReaderTtsChapterCompleteCallback? _onChapterComplete;
  ReaderTtsSegmentCallback? _onSegmentChanged;

  bool get isSpeaking => _service.isSpeaking;
  bool get isPaused => _service.isPaused;
  int get paragraphIndex => _service.segmentIndex;
  int get paragraphCount => _service.segmentCount;
  double get rate => _service.rate;
  double get pitch => _service.pitch;
  String? get voiceName => _service.voiceName;

  ReaderTtsSegment? get currentSegment => _service.currentSegment;

  Future<void> init({
    double rate = 0.5,
    VoidCallback? onStateChanged,
    VoidCallback? onParagraphChanged,
    ReaderTtsSegmentCallback? onSegmentChanged,
    ReaderTtsChapterCompleteCallback? onChapterComplete,
  }) async {
    _onStateChanged = onStateChanged;
    _onParagraphChanged = onParagraphChanged;
    _onSegmentChanged = onSegmentChanged;
    _onChapterComplete = onChapterComplete;
    await _service.ensureInitialized(
      rate: rate,
      onStateChanged: () {
        _onStateChanged?.call();
        _onParagraphChanged?.call();
      },
      onSegmentChanged: (seg) {
        _onSegmentChanged?.call(seg);
        _onParagraphChanged?.call();
      },
      onChapterComplete: _onChapterComplete,
    );
  }

  void setChapterContent(String content, {int startOffset = 0}) {
    final plain = ReaderTextCleaner.cleanForTts(content);
    _service.setChapterPlainText(plain, startOffset: startOffset);
  }

  Future<void> start({int? fromParagraphIndex}) async {
    await _service.start(fromSegmentIndex: fromParagraphIndex);
  }

  void pause() => _service.pause();

  Future<void> resume() async => _service.resume();

  void stop() => _service.stop();

  Future<void> nextParagraph() async => _service.nextSegment();

  Future<void> prevParagraph() async => _service.prevSegment();

  Future<void> goToParagraph(int index) async => _service.goToSegment(index);

  Future<void> setRate(double rate) async => _service.setRate(rate);

  Future<void> setPitch(double pitch) async => _service.setPitch(pitch);

  Future<void> setVoice(String? name) async => _service.setVoice(name);

  Future<List<Map<String, String>>> listVoices() => _service.listVoices();

  void setSleepTimerMinutes(int minutes) =>
      _service.setSleepTimerMinutes(minutes);

  void pauseForAudioFocusLoss() => _service.pauseForAudioFocusLoss();

  Future<void> resumeAfterAudioFocusGain() =>
      _service.resumeAfterAudioFocusGain();

  void dispose() => _service.dispose();

  String get currentParagraph => _service.currentSegment?.text ?? '';
}
