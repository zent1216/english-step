import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/speak_check_sheet.dart';
import '../widgets/pron_text.dart';

/// 단어장: 오늘 복습할 개수, 복습 시작, 전체 목록(듣기/삭제).
class VocabScreen extends StatelessWidget {
  const VocabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('단어장')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.vocab.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(Icons.bookmark_add_rounded, size: 34, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('아직 담은 표현이 없어요', style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '이야기나 가사에서 노란 표현을 누르고\n"단어장에 담기"를 해보세요.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          final due = state.dueWords();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('오늘 복습할 표현',
                                style: TextStyle(color: scheme.onPrimaryContainer)),
                            Text(
                              '${due.length}개',
                              style: text.headlineMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontFamily: monoFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: due.isEmpty
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ReviewScreen(items: due)),
                                ),
                        child: const Text('복습 시작'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('담은 표현 ${state.vocab.length}개', style: text.titleSmall),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final v in state.vocab) _VocabTile(item: v),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VocabTile extends StatelessWidget {
  const _VocabTile({required this.item});
  final VocabItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(item.word, style: englishStyle(context, size: 17).copyWith(height: 1.3)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [PronText(item.word, size: 13), Text(item.gloss)],
      ),
      leading: Tooltip(
        message: '복습 단계 ${item.box}/${reviewIntervalsDays.length - 1}',
        child: SizedBox(
          width: 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var b = reviewIntervalsDays.length - 1; b >= 1; b--)
                Container(
                  width: 18,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: item.box >= b ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '듣기',
            icon: Icon(Icons.volume_up_outlined, color: scheme.primary),
            onPressed: () =>
                Speaker.instance.speak(item.word, rate: AppState.instance.speechRate),
          ),
          SpeakCheckButton(item.word, ko: item.gloss),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              AppState.instance.removeWord(item);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text('"${item.word}" 삭제함'),
                  action: SnackBarAction(
                    label: '되돌리기',
                    onPressed: () => AppState.instance.restoreWord(item),
                  ),
                ));
            },
          ),
        ],
      ),
    );
  }
}

/// 복습 카드: 앞면은 표현, "뜻 보기"로 뒷면. "알아요"/"아직 헷갈려요".
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.items});
  final List<VocabItem> items;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<VocabItem> _queue = [...widget.items];
  late final int _total = _queue.length;
  int _known = 0;
  bool _flipped = false;
  bool _speakMode = false; // true: 한국어 뜻을 보고 영어로 말해서 답하기(말해보카 방식)

  void _answer(bool known) {
    final item = _queue.removeAt(0);
    AppState.instance.review(item, known: known);
    setState(() {
      if (known) {
        _known++;
      } else {
        _queue.add(item); // 헷갈린 표현은 이번 복습 끝에 한 번 더
      }
      _flipped = false;
    });
  }

  /// 말해서 답하기: 80% 이상 알아들으면 정답(알아요) 처리, 아니면 정답을 보여준다.
  Future<void> _speakAnswer(VocabItem item) async {
    final score = await showSpeakCheckSheet(context, item.word, ko: item.gloss, quiz: true);
    if (!mounted || score == null) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (score >= 80) {
      messenger.showSnackBar(SnackBar(content: Text('정답! $score%')));
      _answer(true);
    } else {
      messenger.showSnackBar(SnackBar(content: Text('$score% · 정답을 확인하고 골라주세요')));
      setState(() => _flipped = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('복습  $_known / $_total')),
      body: SafeArea(
        child: _queue.isEmpty ? _done(context) : _card(context, scheme, text),
      ),
    );
  }

  Widget _done(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('오늘 복습 끝!', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('$_total개 표현을 복습했어요.'),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
          ],
        ),
      );

  Widget _card(BuildContext context, ColorScheme scheme, TextTheme text) {
    final item = _queue.first;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(value: _known / _total),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('보고 떠올리기'), icon: Icon(Icons.visibility)),
              ButtonSegment(value: true, label: Text('말해서 답하기'), icon: Icon(Icons.mic)),
            ],
            selected: {_speakMode},
            onSelectionChanged: (v) => setState(() {
              _speakMode = v.first;
              _flipped = false;
            }),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_speakMode && !_flipped) ...[
                      Text(item.gloss, textAlign: TextAlign.center, style: text.headlineSmall),
                      const SizedBox(height: 12),
                      Text('이 뜻을 영어로 말해보세요',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ] else ...[
                      Text(
                        item.word,
                        textAlign: TextAlign.center,
                        style: englishStyle(context, size: 28).copyWith(height: 1.3),
                      ),
                      PronText(item.word, size: 16, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ListenSpeakButtons(item.word, ko: item.gloss),
                    ],
                    if (_flipped) ...[
                      const Divider(height: 40),
                      Text(item.gloss, textAlign: TextAlign.center, style: text.titleLarge),
                      if (item.context.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          item.context,
                          textAlign: TextAlign.center,
                          style: englishStyle(context, size: 15)
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: _flipped
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _answer(false),
                          child: const Text('아직 헷갈려요'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _answer(true),
                          child: const Text('알아요'),
                        ),
                      ),
                    ],
                  )
                : _speakMode
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _flipped = true),
                              child: const Text('정답 보기'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.mic),
                              label: const Text('말해서 답하기'),
                              onPressed: () => _speakAnswer(item),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () => setState(() => _flipped = true),
                          child: const Text('뜻 보기'),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
