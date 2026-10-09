import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../models.dart';
import '../pronunciation.dart';
import '../speech/moonshine.dart';
import '../speech/recorder.dart';
import '../theme.dart';

/// 말하기(따라 말하기) 버튼. 듣기 버튼 옆에 짝으로 둔다. 누르면 [showSpeakCheckSheet]가 열린다.
class SpeakCheckButton extends StatelessWidget {
  const SpeakCheckButton(this.target,
      {super.key, this.ko = '', this.quiz = false, this.onBeforeOpen});
  final String target;
  final String ko;

  /// true면 영어를 숨기고 한국어 뜻만 보고 말하게 한다.
  final bool quiz;

  /// 시트를 열기 전에 할 일(예: 노래 일시정지).
  final VoidCallback? onBeforeOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: '말하기(발음 체크)',
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: scheme.tertiaryContainer,
        foregroundColor: scheme.onTertiaryContainer,
      ),
      icon: const Icon(Icons.mic, size: 20),
      onPressed: () {
        onBeforeOpen?.call();
        showSpeakCheckSheet(context, target, ko: ko, quiz: quiz);
      },
    );
  }
}

/// 글자가 달린 "듣기 / 말하기" 버튼 한 쌍. 카드나 바텀시트처럼 자리가 넉넉한 곳에 쓴다.
class ListenSpeakButtons extends StatelessWidget {
  const ListenSpeakButtons(this.target, {super.key, this.ko = ''});
  final String target;
  final String ko;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.volume_up),
          label: const Text('듣기'),
          onPressed: () => Speaker.instance.speak(target, rate: AppState.instance.speechRate),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.tertiary,
            foregroundColor: scheme.onTertiary,
          ),
          icon: const Icon(Icons.mic),
          label: const Text('말하기'),
          onPressed: () => showSpeakCheckSheet(context, target, ko: ko),
        ),
      ],
    );
  }
}

/// 따라 말하기 시트를 연다. [quiz]면 영어 정답을 숨기고 한국어 뜻만 보여준 채 말하게 한다.
/// 시트가 닫히면 이번에 받은 최고 점수(0~100, 한 번도 안 했으면 null)를 돌려준다.
Future<int?> showSpeakCheckSheet(BuildContext context, String target,
    {String ko = '', bool quiz = false}) async {
  Speaker.instance.stop();
  int? best;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SpeakCheckSheet(
      target: target,
      ko: ko,
      quiz: quiz,
      onBest: (v) => best = v,
    ),
  );
  return best;
}


// 예비 엔진(폰 기본 음성 인식). Moonshine 모델을 받기 전에만 쓴다.
final _stt = SpeechToText();

class _SpeakCheckSheet extends StatefulWidget {
  const _SpeakCheckSheet({
    required this.target,
    required this.ko,
    required this.quiz,
    required this.onBest,
  });
  final String target;
  final String ko;
  final bool quiz;
  final ValueChanged<int> onBest;

  @override
  State<_SpeakCheckSheet> createState() => _SpeakCheckSheetState();
}

class _SpeakCheckSheetState extends State<_SpeakCheckSheet> {
  final _engine = MoonshineEngine.instance;
  final _recorder = TakeRecorder();
  final _player = AudioPlayer();

  bool _listening = false; // 녹음(듣는) 중
  bool _decoding = false; // Moonshine이 받아쓰는 중
  double _level = 0;
  String _heard = '';
  SpeakResult? _result;
  String? _error;
  int? _best;
  String? _takePath; // 내 목소리 다시 듣기

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngine);
    _engine.init();
    _recorder.onLevel = (v) {
      if (mounted && _listening) setState(() => _level = v);
    };
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngine);
    _recorder.cancel();
    _recorder.dispose();
    _player.dispose();
    _stt.cancel();
    super.dispose();
  }

  void _onEngine() {
    if (mounted) setState(() {});
  }

  bool get _useMoonshine => _engine.isReady;

  Future<void> _start() async {
    await Speaker.instance.stop();
    await _player.stop();
    setState(() {
      _error = null;
      _result = null;
      _heard = '';
      _takePath = null;
    });
    if (_useMoonshine) {
      await _startMoonshine();
    } else {
      await _startFallback();
    }
  }

  Future<void> _stop() async {
    if (_useMoonshine) {
      await _recorder.stop();
    } else {
      await _stt.stop();
      if (mounted && _result == null) _finish(_heard);
    }
  }

  // ---- Moonshine: 녹음 → 폰 안에서 받아쓰기 ----
  Future<void> _startMoonshine() async {
    if (!await _recorder.hasPermission()) {
      setState(() => _error = '마이크 권한이 필요해요. 설정에서 이 앱의 마이크를 허용해주세요.');
      return;
    }
    setState(() {
      _listening = true;
      _level = 0;
    });
    final Float32List samples;
    try {
      samples = await _recorder.record();
    } catch (e) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = '녹음을 시작하지 못했어요($e).';
        });
      }
      return;
    }
    if (!mounted) return;
    if (!_recorder.heardSpeech || samples.length < MoonshineEngine.sampleRate ~/ 3) {
      setState(() => _listening = false);
      _finish('');
      return;
    }
    setState(() {
      _listening = false;
      _decoding = true;
    });
    // 스피너가 먼저 그려지도록 한 프레임 쉰다(받아쓰기는 잠깐 화면을 붙잡는다).
    await Future<void>.delayed(const Duration(milliseconds: 60));
    try {
      final text = _engine.transcribe(samples);
      _takePath = _engine.saveWave(samples);
      if (!mounted) return;
      setState(() {
        _decoding = false;
        _heard = text;
      });
      _finish(text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _decoding = false;
          _error = '음성 인식 오류($e).';
        });
      }
    }
  }

  // ---- 예비: 폰 기본 음성 인식 ----
  Future<void> _startFallback() async {
    final ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '음성 인식을 쓸 수 없어요. 마이크 권한을 허용했는지 확인하거나, '
          '위의 정확한 음성 인식을 받아주세요.');
      return;
    }
    setState(() => _listening = true);
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (v) {
        if (mounted) setState(() => _level = ((v + 2) / 12).clamp(0.0, 1.0));
      },
      listenOptions: SpeechListenOptions(
        localeId: 'en_US',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() => _heard = r.recognizedWords);
    if (r.finalResult) _finish(r.recognizedWords);
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.notListeningStatus || status == SpeechToText.doneStatus) {
      setState(() => _listening = false);
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      if (e.errorMsg.contains('no_match') || e.errorMsg.contains('speech_timeout')) {
        _result = checkSpeech(widget.target, '');
      } else {
        _error = '음성 인식 오류(${e.errorMsg}). 잠시 후 다시 해보세요.';
      }
    });
  }

  void _finish(String heard) {
    final r = checkSpeech(widget.target, heard);
    setState(() {
      _listening = false;
      _result = r;
      if (heard.trim().isNotEmpty && (_best == null || r.score > _best!)) _best = r.score;
    });
    if (_best != null) widget.onBest(_best!);
  }

  // ---- 화면 ----
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = _result;
    final good = AppColors.of(context).good;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.quiz ? '영어로 말해보세요' : '따라 말하기',
                      style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
                _EngineChip(moonshine: _useMoonshine),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.quiz
                  ? '뜻을 보고 영어로 말하면 정답과 비교해요. 80% 이상이면 정답!'
                  : '듣고 → 마이크를 누르고 따라 말해보세요.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (!_useMoonshine) ...[
              const SizedBox(height: 14),
              _ModelCard(engine: _engine),
            ],
            const SizedBox(height: 18),
            // 문장(결과가 나오면 단어별 색칠)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.quiz && r == null)
                    Text(widget.ko, style: text.titleLarge)
                  else if (r == null)
                    Text(plainText(widget.target), style: englishStyle(context, size: 22))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        for (final w in r.words)
                          Text(
                            w.word,
                            style: englishStyle(context, size: 22).copyWith(
                              color: !w.counted ? null : (w.ok ? good : scheme.error),
                              fontWeight: w.counted && !w.ok ? FontWeight.w700 : null,
                              decoration: w.counted && !w.ok ? TextDecoration.underline : null,
                              decorationColor: scheme.error,
                            ),
                          ),
                      ],
                    ),
                  if (widget.ko.isNotEmpty && !(widget.quiz && r == null)) ...[
                    const SizedBox(height: 6),
                    Text(widget.ko, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 들은 말
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hearing, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _decoding
                        ? '받아쓰는 중…'
                        : _listening
                            ? '듣는 중… 말을 마치면 자동으로 멈춰요'
                            : (_heard.isEmpty ? '아직 말하지 않았어요' : '“$_heard”'),
                    style: englishStyle(context, size: 16)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (r != null) ...[
              const SizedBox(height: 16),
              _ScoreRow(result: r, best: _best),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            // 큰 마이크 버튼 + 소리 크기 링
            Center(
              child: _MicButton(
                listening: _listening,
                busy: _decoding,
                level: _level,
                onTap: _decoding ? null : (_listening ? _stop : _start),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _listening ? '다 말했으면 눌러서 끝내기' : (r == null ? '눌러서 말하기' : '다시 하기'),
                style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('원어민 듣기'),
                    onPressed: _listening || _decoding || (widget.quiz && r == null)
                        ? null
                        : () => Speaker.instance
                            .speak(widget.target, rate: AppState.instance.speechRate),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.record_voice_over_rounded),
                    label: const Text('내 목소리'),
                    onPressed: _takePath == null || _listening
                        ? null
                        : () => _player.play(DeviceFileSource(_takePath!)),
                  ),
                ),
              ],
            ),
            if (widget.quiz && r != null) ...[
              const SizedBox(height: 10),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
            ],
          ],
        ),
      ),
    );
  }
}

class _EngineChip extends StatelessWidget {
  const _EngineChip({required this.moonshine});
  final bool moonshine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: moonshine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        moonshine ? 'Moonshine' : '기본 인식',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: moonshine ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Moonshine 모델 받기 안내/진행 카드.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.engine});
  final MoonshineEngine engine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final Widget body;
    switch (engine.state) {
      case ModelState.downloading:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정확한 음성 인식 받는 중… ${(engine.progress * 100).round()}%',
                style: text.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: engine.progress, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 6),
            Text('창을 닫아도 계속 받아요.', style: text.bodySmall),
          ],
        );
      case ModelState.extracting:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설치하는 중… (1분 정도 걸려요)', style: text.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(borderRadius: BorderRadius.circular(4)),
          ],
        );
      default:
        body = Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('정확한 음성 인식(Moonshine) 받기', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    engine.error ??
                        '폰 안에서 도는 AI 음성 인식이에요. 한 번만 받으면 인터넷 없이 써요. '
                            '약 ${MoonshineEngine.approxMb}MB · Wi-Fi 권장',
                    style: text.bodySmall?.copyWith(
                        color: engine.error != null ? scheme.error : scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: engine.state == ModelState.checking ? null : engine.download,
              child: Text(engine.error != null ? '다시' : '받기'),
            ),
          ],
        );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        color: scheme.primaryContainer.withValues(alpha: 0.25),
      ),
      child: body,
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.result, required this.best});
  final SpeakResult result;
  final int? best;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = AppColors.of(context).good;
    final color = result.score >= 70 ? good : scheme.error;
    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: result.score / 100,
                strokeWidth: 6,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
                strokeCap: StrokeCap.round,
              ),
              Text('${result.score}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message, style: Theme.of(context).textTheme.bodyLarge),
              if (best != null)
                Text('최고 기록 $best점',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.busy,
    required this.level,
    required this.onTap,
  });
  final bool listening;
  final bool busy;
  final double level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = listening ? 88 + level * 26 : 88.0;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (listening ? scheme.error : scheme.primary).withValues(alpha: 0.15),
            ),
          ),
          Material(
            color: listening ? scheme.error : scheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 76,
                height: 76,
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: scheme.onPrimary),
                      )
                    : Icon(listening ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 36, color: listening ? scheme.onError : scheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
