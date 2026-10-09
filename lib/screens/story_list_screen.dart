import 'package:flutter/material.dart';

import '../app_state.dart';
import '../content.dart';
import '../models.dart';
import '../theme.dart';
import '../update_check.dart';
import '../widgets/marked_text.dart';
import 'sentence_screens.dart';
import 'story_reader_screen.dart';

class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final done = stories.where((s) => state.doneStories.contains(s.id)).length;
            final due = state.dueWords().length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('영어 한 걸음',
                              style: text.labelLarge?.copyWith(color: scheme.primary)),
                          const SizedBox(height: 2),
                          Text('오늘도 한 걸음 걸어볼까요?', style: text.headlineSmall),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '듣기 속도',
                      icon: const Icon(Icons.speed_rounded),
                      onPressed: () => showSpeechRateSheet(context),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: '앱 정보·업데이트',
                      icon: const Icon(Icons.info_outline_rounded),
                      onPressed: () => showAppInfoSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _StatTile(label: '이야기', value: '$done/${stories.length}')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(label: 'Lv.0 세트', value: '${state.doneSets.length}/20')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(label: '오늘 복습', value: '$due개')),
                  ],
                ),
                const SizedBox(height: 20),
                _Lv0Card(done: state.doneSets.length),
                const SizedBox(height: 24),
                Text('이야기', style: text.titleLarge),
                const SizedBox(height: 2),
                Text('수준보다 살짝 어려운 이야기를 듣고, 읽고, 따라 말해보세요.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                for (final s in stories) ...[
                  _StoryCard(story: s, done: state.doneStories.contains(s.id)),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.of(context).subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: text.titleLarge?.copyWith(fontSize: 19)),
        ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? scheme.onPrimaryContainer : Colors.white;
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [scheme.primaryContainer, scheme.surfaceContainerHighest]
                : [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.45)!],
          ),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SentenceSetListScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('처음이라면 여기부터',
                          style: text.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: fg),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Lv.0 첫걸음 문장', style: text.headlineSmall?.copyWith(color: fg)),
                const SizedBox(height: 4),
                Text('"How are you?" 같은 짧은 문장 200개 · 10개씩 20세트',
                    style: text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.9))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: done / 20,
                          minHeight: 6,
                          color: fg,
                          backgroundColor: fg.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done/20', style: text.titleSmall?.copyWith(color: fg)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 레벨마다 다른 색 배지.
Color levelColor(int level) => const [
      Color(0xFF16A34A),
      Color(0xFF0EA5E9),
      Color(0xFF6366F1),
      Color(0xFFF2643E),
    ][(level - 1).clamp(0, 3)];

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.done});
  final Story story;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lc = levelColor(story.level);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoryReaderScreen(story: story)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: lc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Lv.${story.level} ${story.levelName}',
                      style: text.labelMedium?.copyWith(color: lc, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${story.sentences.length}문장',
                      style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  if (done)
                    Icon(Icons.check_circle_rounded, size: 22, color: AppColors.of(context).good)
                  else
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(story.title,
                  style: englishStyle(context, size: 21)
                      .copyWith(height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text(story.titleKo, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '핵심 표현  ',
                        style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    TextSpan(
                      text: story.keyExpression,
                      style: englishStyle(context, size: 15).copyWith(
                        background: Paint()..color = markerColor(context),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
