import 'package:flutter/material.dart';

import '../app_state.dart';
import '../sentences.dart';
import '../theme.dart';
import '../widgets/marked_text.dart';
import '../widgets/speak_check_sheet.dart';

/// Lv.0 첫걸음 문장: 20세트 목록.
class SentenceSetListScreen extends StatelessWidget {
  const SentenceSetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Lv.0 첫걸음 문장')),
      body: FutureBuilder<List<PracticeSentence>>(
        future: loadLv0Sentences(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final sets = chunkSets(snap.data!);
          return ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  '자주 쓰는 단어로만 된 짧은 문장이에요. 하루 한 세트씩, 듣고 → 따라 말해보세요.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (var i = 0; i < sets.length; i++) _setTile(context, sets, i),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  tatoebaCredit,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _setTile(BuildContext context, List<List<PracticeSentence>> sets, int i) {
    final scheme = Theme.of(context).colorScheme;
    final done = AppState.instance.doneSets.contains(setId(i));
    return Material(
      color: done ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SentencePracticeScreen(sets: sets, index: i)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${i + 1}',
              style: TextStyle(
                fontFamily: monoFont,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: done ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
            Text(
              done ? '완료' : '세트',
              style: TextStyle(
                fontSize: 11,
                color: done ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 한 세트(10문장) 연습. "듣고 이해"는 영어 → 해석, "말해보기"는 해석 → 영어.
class SentencePracticeScreen extends StatefulWidget {
  const SentencePracticeScreen({super.key, required this.sets, required this.index});
  final List<List<PracticeSentence>> sets;
  final int index;

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  bool _speakMode = false; // false: 듣고 이해, true: 말해보기
  final _revealed = <int>{};

  List<PracticeSentence> get items => widget.sets[widget.index];

  @override
  void dispose() {
    Speaker.instance.stop();
    super.dispose();
  }

  void _speak(String en) => Speaker.instance.speak(en, rate: AppState.instance.speechRate);

  @override
  Widget build(BuildContext context) {
    final last = widget.index == widget.sets.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Lv.0 · ${widget.index + 1}세트'),
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
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('듣고 이해'), icon: Icon(Icons.hearing)),
              ButtonSegment(value: true, label: Text('말해보기'), icon: Icon(Icons.record_voice_over)),
            ],
            selected: {_speakMode},
            onSelectionChanged: (s) => setState(() {
              _speakMode = s.first;
              _revealed.clear();
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _speakMode
                ? '한국어를 보고 영어로 소리 내어 말해본 뒤, 눌러서 정답을 확인하세요.'
                : '영어를 듣고 뜻을 떠올려 본 뒤, 눌러서 해석을 확인하세요.',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            _card(i),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: Icon(last ? Icons.check : Icons.arrow_forward),
            label: Text(last ? '완료' : '완료하고 다음 세트'),
            onPressed: () {
              AppState.instance.markSetDone(setId(widget.index));
              if (last) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SentencePracticeScreen(sets: widget.sets, index: widget.index + 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _card(int i) {
    final scheme = Theme.of(context).colorScheme;
    final s = items[i];
    final open = _revealed.contains(i);
    final enText = Text(s.en, style: englishStyle(context, size: 20));
    final koText = Text(s.ko, style: const TextStyle(fontSize: 16));
    final hidden = Text(
      _speakMode ? '눌러서 영어 보기' : '눌러서 해석 보기',
      style: TextStyle(color: scheme.outline),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() => open ? _revealed.remove(i) : _revealed.add(i));
          if (!open && _speakMode) _speak(s.en);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_speakMode) koText else enText,
                    const SizedBox(height: 6),
                    if (open) (_speakMode ? enText : koText) else hidden,
                    if (open)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          s.src,
                          style: TextStyle(fontSize: 10, color: scheme.outline),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (!_speakMode || open)
                    IconButton(
                      tooltip: '듣기',
                      icon: Icon(Icons.volume_up_outlined, color: scheme.primary),
                      onPressed: () => _speak(s.en),
                    ),
                  if (!_speakMode || open) SpeakCheckButton(s.en, ko: s.ko),
                  ListenableBuilder(
                    listenable: AppState.instance,
                    builder: (context, _) {
                      final saved = AppState.instance.hasWord(s.en);
                      return IconButton(
                        tooltip: saved ? '단어장에 있음' : '단어장에 담기',
                        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_add_outlined),
                        onPressed: saved
                            ? null
                            : () => AppState.instance.addWord(s.en, s.ko, 'Lv.0 첫걸음 문장'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
