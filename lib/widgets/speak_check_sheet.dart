import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../models.dart';
import '../pronunciation.dart';
import '../theme.dart';

/// 따라 말하기 버튼. 누르면 [showSpeakCheckSheet]가 열린다.
class SpeakCheckButton extends StatelessWidget {
  const SpeakCheckButton(this.target, {super.key, this.ko = ''});
  final String target;
  final String ko;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: '따라 말하기(발음 체크)',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.mic_none, color: Theme.of(context).colorScheme.primary),
        onPressed: () => showSpeakCheckSheet(context, target, ko: ko),
      );
}

Future<void> showSpeakCheckSheet(BuildContext context, String target, {String ko = ''}) {
  Speaker.instance.stop();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SpeakCheckSheet(target: target, ko: ko),
  );
}

// 앱 전체에서 하나만 쓴다(초기화는 처음 한 번).
final _stt = SpeechToText();

class _SpeakCheckSheet extends StatefulWidget {
  const _SpeakCheckSheet({required this.target, required this.ko});
  final String target;
  final String ko;

  @override
  State<_SpeakCheckSheet> createState() => _SpeakCheckSheetState();
}

class _SpeakCheckSheetState extends State<_SpeakCheckSheet> {
  bool _listening = false;
  String _heard = '';
  SpeakResult? _result;
  String? _error;
  int? _best;

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    await Speaker.instance.stop();
    setState(() {
      _error = null;
      _result = null;
      _heard = '';
    });
    final ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '음성 인식을 쓸 수 없어요. 마이크 권한을 허용했는지, '
          'Google 음성 인식이 켜져 있는지 확인해주세요.');
      return;
    }
    setState(() => _listening = true);
    await _stt.listen(
      onResult: _onResult,
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

  Future<void> _stop() async {
    await _stt.stop();
    // 최종 결과는 _onResult(finalResult)에서 처리된다. 결과가 안 오면 지금까지 들은 걸로 채점.
    if (mounted && _result == null) _finish(_heard);
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
      // 아무 말도 안 했을 때(no_match, speech_timeout)는 빈 결과로 안내한다.
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
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('따라 말하기', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('듣고 → 마이크를 누르고 따라 말해보세요. 폰이 알아들은 단어는 초록, 못 알아들은 단어는 빨강으로 표시돼요.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (r == null)
              Text(plainText(widget.target), style: englishStyle(context, size: 21))
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in r.words)
                    Text(
                      w.word,
                      style: englishStyle(context, size: 21).copyWith(
                        color: !w.counted
                            ? null
                            : w.ok
                                ? Colors.green.shade600
                                : scheme.error,
                        decoration: w.counted && !w.ok ? TextDecoration.underline : null,
                        decorationColor: scheme.error,
                        fontWeight: w.counted && !w.ok ? FontWeight.w600 : null,
                      ),
                    ),
                ],
              ),
            if (widget.ko.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.ko, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_listening ? '듣는 중…' : '폰이 알아들은 말',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    _heard.isEmpty ? (_listening ? '말해보세요' : '-') : _heard,
                    style: englishStyle(context, size: 17),
                  ),
                ],
              ),
            ),
            if (r != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${r.score}%',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: monoFont,
                          color: r.score >= 70 ? Colors.green.shade600 : scheme.error)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.message)),
                ],
              ),
              if (_best != null)
                Text('최고 기록 $_best%', style: TextStyle(fontSize: 12, color: scheme.outline)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.volume_up),
                    label: const Text('듣기'),
                    onPressed: _listening
                        ? null
                        : () => Speaker.instance
                            .speak(widget.target, rate: AppState.instance.speechRate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _listening ? scheme.error : null,
                    ),
                    icon: Icon(_listening ? Icons.stop : Icons.mic),
                    label: Text(_listening ? '다 말했어요' : (r == null ? '따라 말하기' : '다시 하기')),
                    onPressed: _listening ? _stop : _start,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
