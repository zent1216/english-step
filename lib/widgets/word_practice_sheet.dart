/// 단어 하나 발음 연습(말해보카 방식). 따라 말하기 결과에서 빨간·주황 단어를 누르면 열린다.
///
/// - 열자마자 원어민 소리가 나온다. 보통 / 천천히 듣기.
/// - 큰 단어 + 뜻(기기 내 번역) + 나온 문장(단어 강조).
/// - "3번 따라 말하기": 알아들으면(70점 이상) 점이 하나씩 채워진다.
/// - 단어장에 담기 버튼이 단어 바로 옆에 있다.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../pronunciation.dart';
import '../speech/moonshine.dart';
import '../speech/recorder.dart';
import '../theme.dart';
import '../translate.dart';
import 'speak_check_sheet.dart';
import 'pron_text.dart';

/// 화면용 단어 정리: 앞뒤 문장부호를 뗀다("home." → "home", "I'm"은 그대로).
String cleanWord(String w) => w.replaceAll(RegExp(r"^[^A-Za-z0-9]+|[^A-Za-z0-9]+$"), '');

Future<void> showWordPracticeSheet(
  BuildContext context,
  String word, {
  String sentence = '',
  String sentenceKo = '',
}) async {
  final w = cleanWord(word);
  if (w.isEmpty) return;
  Speaker.instance.stop();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _WordPracticeSheet(word: w, sentence: plainText(sentence), sentenceKo: sentenceKo),
  );
}

const _goal = 3; // 따라 말하기 목표 횟수
const _passScore = 70;

class _WordPracticeSheet extends StatefulWidget {
  const _WordPracticeSheet({required this.word, required this.sentence, required this.sentenceKo});
  final String word;
  final String sentence;
  final String sentenceKo;

  @override
  State<_WordPracticeSheet> createState() => _WordPracticeSheetState();
}

class _WordPracticeSheetState extends State<_WordPracticeSheet> {
  final _engine = MoonshineEngine.instance;
  final _recorder = TakeRecorder();

  String? _gloss; // 단어 뜻
  bool _glossLoading = false;
  bool _glossNeedsDownload = false;

  int _passes = 0;
  bool _listening = false;
  bool _decoding = false;
  double _level = 0;
  String? _heard;
  int? _lastScore;
  String? _error;

  @override
  void initState() {
    super.initState();
    _engine.init();
    _recorder.onLevel = (v) {
      if (mounted && _listening) setState(() => _level = v);
    };
    _prepareGloss();
    // 시트가 올라온 뒤 원어민 소리.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _say(0.85);
    });
  }

  @override
  void dispose() {
    _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _say(double rate) => Speaker.instance.speak(widget.word, rate: rate).catchError((_) {});

  Future<void> _prepareGloss() async {
    if (!canTranslateOnDevice) return;
    try {
      if (await translationModelsReady()) {
        await _translate();
      } else if (mounted) {
        setState(() => _glossNeedsDownload = true);
      }
    } catch (_) {}
  }

  Future<void> _translate() async {
    setState(() {
      _glossLoading = true;
      _glossNeedsDownload = false;
    });
    try {
      final out = await translateToKorean([widget.word]);
      if (mounted) setState(() => _gloss = out.first);
    } catch (_) {
      if (mounted) setState(() => _glossNeedsDownload = true);
    } finally {
      if (mounted) setState(() => _glossLoading = false);
    }
  }

  // ---- 따라 말하기 ----
  Future<void> _speak() async {
    await Speaker.instance.stop();
    if (!_engine.isReady || AppState.instance.usePhoneAsr) {
      // Moonshine이 없으면 기존 따라 말하기 시트(폰 기본 인식)로.
      if (!mounted) return;
      final s = await showSpeakCheckSheet(context, widget.word, ko: _gloss ?? '');
      if (s != null) _score(s, null);
      return;
    }
    if (!await _recorder.hasPermission()) {
      setState(() => _error = '마이크 권한이 필요해요. 설정에서 이 앱의 마이크를 허용해주세요.');
      return;
    }
    setState(() {
      _error = null;
      _heard = null;
      _lastScore = null;
      _listening = true;
      _level = 0;
    });
    final Float32List samples;
    try {
      samples = await _recorder.record(noisy: AppState.instance.noisyMode);
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
    if (!_recorder.heardSpeech) {
      setState(() {
        _listening = false;
        _error = '목소리가 들리지 않았어요. 다시 눌러 말해보세요.';
      });
      return;
    }
    setState(() {
      _listening = false;
      _decoding = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 60));
    try {
      var heard = '';
      var best = -1;
      for (final c in _engine.transcribeCandidates(samples)) {
        final s = checkSpeech(widget.word, c).score;
        if (s > best) {
          best = s;
          heard = c;
        }
      }
      if (!mounted) return;
      setState(() => _decoding = false);
      _score(best < 0 ? 0 : best, heard);
    } catch (e) {
      if (mounted) {
        setState(() {
          _decoding = false;
          _error = '음성 인식 오류($e).';
        });
      }
    }
  }

  void _score(int score, String? heard) {
    AppState.instance.recordSpeakScore(widget.word, score);
    setState(() {
      _lastScore = score;
      _heard = heard;
      if (score >= _passScore && _passes < _goal) _passes++;
    });
    if (score < _passScore) _say(0.7); // 틀리면 천천히 다시 들려준다
  }

  String get _feedback {
    final s = _lastScore;
    if (s == null) return '';
    if (_passes >= _goal) return '3번 성공! 이제 이 단어는 자신 있게 말할 수 있어요.';
    if (s >= 100) return '정확해요! ${_goal - _passes}번 더 해볼까요?';
    if (s >= _passScore) return '거의 맞았어요! 통과. ${_goal - _passes}번 더!';
    return '조금 달랐어요. 천천히 들려줄게요. 입 모양을 크게 해서 다시 말해봐요.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final good = AppColors.of(context).good;
    final done = _passes >= _goal;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('단어 발음 연습', style: text.labelLarge?.copyWith(color: scheme.tertiary)),
            const SizedBox(height: 6),
            // 큰 단어 + 단어장에 담기
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.word,
                    style: englishStyle(context, size: 36).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _AddWordButton(
                  word: widget.word,
                  gloss: _gloss,
                  sentence: widget.sentence,
                  sentenceKo: widget.sentenceKo,
                ),
              ],
            ),
            PronText(widget.word, size: 18),
            const SizedBox(height: 2),
            if (_glossLoading)
              Text('뜻 찾는 중…', style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant))
            else if (_gloss != null && _gloss!.isNotEmpty)
              Text(_gloss!, style: text.titleMedium)
            else if (_glossNeedsDownload)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(Icons.translate_rounded, size: 18),
                  label: const Text('뜻 보기 (처음 한 번 번역 모델 약 60MB 받기)'),
                  onPressed: _translate,
                ),
              ),
            if (widget.sentence.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedSentence(sentence: widget.sentence, word: widget.word),
                    if (widget.sentenceKo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.sentenceKo,
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('원어민 듣기'),
                    onPressed: _listening || _decoding ? null : () => _say(0.85),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.slow_motion_video_rounded),
                    label: const Text('천천히'),
                    onPressed: _listening || _decoding ? null : () => _say(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // 3번 따라 말하기 진행
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$_goal번 따라 말하기', style: text.titleSmall),
                const SizedBox(width: 12),
                for (var k = 0; k < _goal; k++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k < _passes ? good : Colors.transparent,
                        border: Border.all(color: k < _passes ? good : scheme.outline, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: _WordMic(
                listening: _listening,
                busy: _decoding,
                done: done,
                level: _level,
                onTap: _decoding ? null : (_listening ? () => _recorder.stop() : _speak),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _decoding
                    ? '받아쓰는 중…'
                    : _listening
                    ? '듣는 중… 말하고 잠시 기다리면 멈춰요'
                    : (done ? '한 번 더 해도 좋아요' : '눌러서 따라 말하기'),
                style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 6),
            const Center(child: NoisyToggle()),
            if (_lastScore != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_lastScore! >= _passScore ? good : scheme.error).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_feedback, style: text.bodyLarge),
                    if (_heard != null && _heard!.trim().isNotEmpty)
                      Text(
                        '들린 말: “${_heard!.trim()}”',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            if (!_engine.isReady) ...[
              const SizedBox(height: 10),
              Text(
                '정확한 음성 인식(Moonshine)을 받으면 이 화면에서 바로 채점해요.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddWordButton extends StatelessWidget {
  const _AddWordButton({
    required this.word,
    required this.gloss,
    required this.sentence,
    required this.sentenceKo,
  });
  final String word;
  final String? gloss;
  final String sentence;
  final String sentenceKo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final saved = AppState.instance.hasWord(word);
        return FilledButton.tonalIcon(
          icon: Icon(saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined),
          label: Text(saved ? '담았어요' : '단어장에 담기'),
          onPressed: saved
              ? null
              : () {
                  final g = (gloss ?? '').isNotEmpty ? gloss! : sentenceKo;
                  AppState.instance.addWord(word, g, sentence);
                  ScaffoldMessenger.maybeOf(
                    context,
                  )?.showSnackBar(SnackBar(content: Text('“$word”를 단어장에 담았어요')));
                },
        );
      },
    );
  }
}

/// 문장 속 연습 단어를 형광펜으로 강조.
class _HighlightedSentence extends StatelessWidget {
  const _HighlightedSentence({required this.sentence, required this.word});
  final String sentence;
  final String word;

  @override
  Widget build(BuildContext context) {
    final base = englishStyle(context, size: 17);
    final key = normalizeWord(word);
    final tokens = sentence.split(' ');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < tokens.length; i++) ...[
            if (i > 0) const TextSpan(text: ' '),
            normalizeWord(tokens[i]) == key
                ? TextSpan(
                    text: tokens[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      backgroundColor: markerColor(context),
                    ),
                  )
                : TextSpan(text: tokens[i]),
          ],
        ],
      ),
    );
  }
}

class _WordMic extends StatelessWidget {
  const _WordMic({
    required this.listening,
    required this.busy,
    required this.done,
    required this.level,
    required this.onTap,
  });
  final bool listening;
  final bool busy;
  final bool done;
  final double level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = AppColors.of(context).good;
    final color = listening ? scheme.error : (done ? good : scheme.tertiary);
    final ring = listening ? 80 + level * 24 : 80.0;
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: ring,
            height: ring,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
          ),
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 70,
                height: 70,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : Icon(
                        listening
                            ? Icons.stop_rounded
                            : (done ? Icons.check_rounded : Icons.mic_rounded),
                        size: 34,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
