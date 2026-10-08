import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/marked_text.dart';
import '../widgets/speak_check_sheet.dart';

/// 이야기 읽기: 문장별 듣기/해석, 전체 듣기, 끝에 이해 확인 퀴즈.
class StoryReaderScreen extends StatefulWidget {
  const StoryReaderScreen({super.key, required this.story});
  final Story story;

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  final _shownKo = <int>{};
  bool _allKo = false;
  int? _playing; // 지금 읽고 있는 문장 번호
  int _playToken = 0; // 전체 듣기를 멈추면 값이 바뀌어 이전 재생 루프가 끝난다
  int? _picked; // 퀴즈에서 고른 답

  Story get story => widget.story;

  @override
  void dispose() {
    _playToken++;
    Speaker.instance.stop();
    super.dispose();
  }

  Future<void> _speakOne(int i) async {
    final token = ++_playToken;
    setState(() => _playing = i);
    await Speaker.instance.speak(story.sentences[i].en, rate: AppState.instance.speechRate);
    if (mounted && token == _playToken) setState(() => _playing = null);
  }

  Future<void> _playAll() async {
    final token = ++_playToken;
    for (var i = 0; i < story.sentences.length; i++) {
      if (!mounted || token != _playToken) return;
      setState(() => _playing = i);
      await Speaker.instance.speak(story.sentences[i].en, rate: AppState.instance.speechRate);
    }
    if (mounted && token == _playToken) setState(() => _playing = null);
  }

  void _stop() {
    _playToken++;
    Speaker.instance.stop();
    setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final playingAll = _playing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Lv.${story.level} ${story.levelName}'),
        actions: [
          IconButton(
            tooltip: '듣기 속도',
            icon: const Icon(Icons.speed),
            onPressed: () => showSpeechRateSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(story.title, style: englishStyle(context, size: 26).copyWith(height: 1.2)),
          Text(story.titleKo, style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                icon: Icon(playingAll ? Icons.stop : Icons.play_arrow),
                label: Text(playingAll ? '멈추기' : '전체 듣기'),
                onPressed: playingAll ? _stop : _playAll,
              ),
              const Spacer(),
              const Text('해석 모두 보기'),
              Switch(value: _allKo, onChanged: (v) => setState(() => _allKo = v)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '노란 표현을 누르면 뜻이 나와요. 문장 번호를 누르면 해석이 보여요.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < story.sentences.length; i++) _sentenceRow(i),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _quiz(),
        ],
      ),
    );
  }

  Widget _sentenceRow(int i) {
    final scheme = Theme.of(context).colorScheme;
    final s = story.sentences[i];
    final showKo = _allKo || _shownKo.contains(i);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: _playing == i ? currentLineColor(context) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => showKo ? _shownKo.remove(i) : _shownKo.add(i)),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontFamily: monoFont,
                  color: showKo ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: showKo ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkedText(s.en),
                  if (showKo)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(s.ko, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '이 문장 듣기',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.volume_up_outlined, color: scheme.primary),
            onPressed: () => _speakOne(i),
          ),
          SpeakCheckButton(s.en, ko: s.ko),
        ],
      ),
    );
  }

  Widget _quiz() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = story.quiz;
    final solved = _picked == q.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이해 확인', style: text.titleMedium),
        const SizedBox(height: 4),
        Text(q.question, style: text.bodyLarge),
        const SizedBox(height: 10),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  backgroundColor: _picked == i
                      ? (i == q.answer ? scheme.primaryContainer : scheme.errorContainer)
                      : null,
                ),
                onPressed: solved
                    ? null
                    : () {
                        setState(() => _picked = i);
                        if (i == q.answer) AppState.instance.markStoryDone(story.id);
                      },
                child: Text(q.options[i]),
              ),
            ),
          ),
        if (_picked != null && !solved)
          Text('다시 한 번 읽어보고 골라보세요.', style: TextStyle(color: scheme.error)),
        if (solved) ...[
          const SizedBox(height: 8),
          _keyExpressionCard(),
        ],
      ],
    );
  }

  Widget _keyExpressionCard() {
    final state = AppState.instance;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('정답! 오늘의 핵심 표현',
                style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              story.keyExpression,
              style: englishStyle(context, size: 20).copyWith(color: scheme.onPrimaryContainer),
            ),
            Text(story.keyExpressionKo, style: TextStyle(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('듣기'),
                  onPressed: () =>
                      Speaker.instance.speak(story.keyExpression, rate: state.speechRate),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.mic),
                  label: const Text('따라 말하기'),
                  onPressed: () => showSpeakCheckSheet(context, story.keyExpression,
                      ko: story.keyExpressionKo),
                ),
                ListenableBuilder(
                  listenable: state,
                  builder: (context, _) => state.hasWord(story.keyExpression)
                      ? const OutlinedButton(onPressed: null, child: Text('단어장에 담았어요'))
                      : FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('단어장에 담기'),
                          onPressed: () => state.addWord(
                            story.keyExpression,
                            story.keyExpressionKo,
                            story.title,
                          ),
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
