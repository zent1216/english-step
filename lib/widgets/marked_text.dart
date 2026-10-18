import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'speak_check_sheet.dart';
import 'word_practice_sheet.dart';
import 'pron_text.dart';

/// `[표현|뜻]` 표시가 들어간 영어 문장. 학습 포인트는 형광펜으로 칠하고, 누르면 뜻 바텀시트를 띄운다.
/// [wordTap]이면 나머지 단어도 하나하나 누를 수 있다 → 단어 설명(뜻·미국식/영국식 발음·따라 말하기) 시트.
class MarkedText extends StatefulWidget {
  const MarkedText(
    this.text, {
    super.key,
    this.size = 18,
    this.ko = '',
    this.wordTap = true,
    this.longPress = false,
    this.onBeforeWord,
    this.style,
  });
  final String text;
  final double size;
  final String ko; // 문장 해석(단어 시트에 같이 보여줌)
  final bool wordTap;
  final bool longPress; // 줄 전체 누르기가 따로 있는 곳(가사, 카드)은 단어를 길게 눌러야 열림
  final VoidCallback? onBeforeWord; // 단어 시트를 열기 전(예: 노래 일시정지)
  final TextStyle? style; // 주면 englishStyle 대신 이 글꼴

  @override
  State<MarkedText> createState() => _MarkedTextState();
}

class _MarkedTextState extends State<MarkedText> {
  final _recognizers = <OneSequenceGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final marker = markerColor(context);
    final spans = <InlineSpan>[];
    for (final s in parseMarked(widget.text)) {
      if (!s.isMarked) {
        if (!widget.wordTap) {
          spans.add(TextSpan(text: s.text));
          continue;
        }
        // 단어마다 누를 수 있게(문장부호·띄어쓰기는 그대로)
        for (final m in RegExp(r"[A-Za-z0-9'’]+|[^A-Za-z0-9'’]+").allMatches(s.text)) {
          final piece = m.group(0)!;
          if (!RegExp('[A-Za-z]').hasMatch(piece)) {
            spans.add(TextSpan(text: piece));
            continue;
          }
          void open() {
            widget.onBeforeWord?.call();
            showWordPracticeSheet(
              context,
              piece.replaceAll('’', "'"),
              sentence: widget.text,
              sentenceKo: widget.ko,
            );
          }

          final OneSequenceGestureRecognizer r = widget.longPress
              ? (LongPressGestureRecognizer()..onLongPress = open)
              : (TapGestureRecognizer()..onTap = open);
          _recognizers.add(r);
          spans.add(TextSpan(text: piece, recognizer: r));
        }
        continue;
      }
      final r = TapGestureRecognizer()
        ..onTap = () => showGlossSheet(context, s.text, s.gloss!, widget.text);
      _recognizers.add(r);
      spans.add(TextSpan(
        text: s.text,
        recognizer: r,
        style: TextStyle(background: Paint()..color = marker),
      ));
    }
    return Text.rich(
      TextSpan(style: widget.style ?? englishStyle(context, size: widget.size), children: spans),
    );
  }
}

/// 학습 포인트의 뜻을 보여주는 바텀시트. 듣기와 단어장 담기를 할 수 있다.
Future<void> showGlossSheet(BuildContext context, String word, String gloss, String sentence) {
  final state = AppState.instance;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(word, style: englishStyle(context, size: 24))),
                IconButton.filledTonal(
                  tooltip: '듣기',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => Speaker.instance.speak(word, rate: state.speechRate),
                ),
                const SizedBox(width: 4),
                SpeakCheckButton(word, ko: gloss),
              ],
            ),
            PronText(word, size: 15),
            const SizedBox(height: 8),
            Text(gloss, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              plainText(sentence),
              style: englishStyle(context, size: 15).copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ListenableBuilder(
                listenable: state,
                builder: (context, _) => state.hasWord(word)
                    ? const OutlinedButton(onPressed: null, child: Text('단어장에 담았어요'))
                    : FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('단어장에 담기'),
                        onPressed: () => state.addWord(word, gloss, sentence),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 듣기 속도 설정 시트 (0.6~1.2배).
Future<void> showSpeechRateSheet(BuildContext context) {
  final state = AppState.instance;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('듣기 속도', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 0.6,
                      max: 1.2,
                      divisions: 6,
                      value: state.speechRate.clamp(0.6, 1.2),
                      label: '${state.speechRate.toStringAsFixed(1)}배',
                      onChanged: state.setSpeechRate,
                    ),
                  ),
                  Text(
                    '${state.speechRate.toStringAsFixed(1)}x',
                    style: const TextStyle(fontFamily: monoFont, fontSize: 16),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('들어보기'),
                onPressed: () => Speaker.instance
                    .speak('This is how fast I will read.', rate: state.speechRate),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
