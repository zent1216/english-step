import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'speak_check_sheet.dart';
import 'pron_text.dart';

/// `[표현|뜻]` 표시가 들어간 영어 문장. 학습 포인트는 형광펜으로 칠하고, 누르면 뜻 바텀시트를 띄운다.
class MarkedText extends StatefulWidget {
  const MarkedText(this.text, {super.key, this.size = 18});
  final String text;
  final double size;

  @override
  State<MarkedText> createState() => _MarkedTextState();
}

class _MarkedTextState extends State<MarkedText> {
  final _recognizers = <TapGestureRecognizer>[];

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
        spans.add(TextSpan(text: s.text));
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
    return Text.rich(TextSpan(style: englishStyle(context, size: widget.size), children: spans));
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
