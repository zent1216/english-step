import 'package:flutter/material.dart';

import '../app_state.dart';
import '../content.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/marked_text.dart';
import 'sentence_screens.dart';
import 'story_reader_screen.dart';

class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('이야기'),
        actions: [
          IconButton(
            tooltip: '듣기 속도',
            icon: const Icon(Icons.speed),
            onPressed: () => showSpeechRateSheet(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: stories.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              final done = stories.where((s) => state.doneStories.contains(s.id)).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '수준보다 살짝 어려운 이야기를 많이 읽고 들어보세요. 완료 $done/${stories.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            if (i == 1) return _Lv0Card(done: state.doneSets.length);
            final s = stories[i - 2];
            return _StoryCard(story: s, done: state.doneStories.contains(s.id));
          },
        ),
      ),
    );
  }
}

/// Lv.0 첫걸음 문장(짧은 문장 200개, 10개씩 20세트)으로 들어가는 카드.
class _Lv0Card extends StatelessWidget {
  const _Lv0Card({required this.done});
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SentenceSetListScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lv.0 첫걸음 문장',
                        style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      '"How are you?" 같은 짧은 문장 200개 · 10개씩 20세트',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Text(
                '$done/20',
                style: TextStyle(
                  fontFamily: monoFont,
                  fontSize: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.done});
  final Story story;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoryReaderScreen(story: story)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Lv.${story.level} ${story.levelName}',
                      style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${story.sentences.length}문장', style: text.labelMedium),
                  const Spacer(),
                  if (done)
                    Row(children: [
                      Icon(Icons.check_circle, size: 18, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text('완료', style: text.labelMedium?.copyWith(color: scheme.primary)),
                    ]),
                ],
              ),
              const SizedBox(height: 10),
              Text(story.title, style: englishStyle(context, size: 21).copyWith(height: 1.2)),
              Text(story.titleKo, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '핵심 표현  ', style: text.labelMedium),
                  TextSpan(
                    text: story.keyExpression,
                    style: englishStyle(context, size: 15).copyWith(
                      background: Paint()..color = markerColor(context),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
