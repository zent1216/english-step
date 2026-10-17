import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../basics/basics_content.dart';
import '../theme.dart';
import '../widgets/pron_text.dart';
import '../widgets/speak_check_sheet.dart';

/// 칸별 색(밝은/어두운 테마 공통)
Color slotColor(Slot s) => switch (s) {
  Slot.q => const Color(0xFF7C4DFF),
  Slot.h => const Color(0xFF00897B),
  Slot.w => const Color(0xFF3E5BF2),
  Slot.a => const Color(0xFFF2643E),
  Slot.o => const Color(0xFF2E9E5B),
  Slot.m => const Color(0xFFB07D00),
};

void _say(String text) => Speaker.instance.speak(text, rate: AppState.instance.speechRate).catchError((_) {});

/// 색깔 조각 하나. [showLabel]이면 아래에 칸 이름.
class ChunkBlock extends StatelessWidget {
  const ChunkBlock(this.chunk, {super.key, this.showLabel = true, this.big = false});
  final Chunk chunk;
  final bool showLabel;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = slotColor(chunk.slot);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: big ? 12 : 10, vertical: big ? 9 : 6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.13),
            border: Border.all(color: c.withValues(alpha: 0.7), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            chunk.text,
            style: englishStyle(context, size: big ? 20 : 17).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              chunk.slot.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
            ),
          ),
      ],
    );
  }
}

/// 6칸 문장 지도 범례
class SentenceMapLegend extends StatelessWidget {
  const SentenceMapLegend({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in Slot.values) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: slotColor(s).withValues(alpha: 0.13),
                  border: Border.all(color: slotColor(s).withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: slotColor(s), fontSize: 13),
                ),
              ),
              if (s != Slot.m) Icon(Icons.chevron_right_rounded, size: 16, color: scheme.outline),
            ],
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          for (final s in Slot.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${s.label}  ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: slotColor(s)),
                    ),
                    TextSpan(text: s.help),
                  ],
                ),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------- 기초 탭 첫 화면 ----------------

class BasicsHomeScreen extends StatelessWidget {
  const BasicsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('기초'), actions: const [PronToggle(), SizedBox(width: 8)]),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final done = AppState.instance.doneBasics;
          final nextIdx = basicsLessons.indexWhere((l) => !done.contains(l.id));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text('영어 문장의 뼈대부터', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '외우지 말고 조립해요. 영어 문장은 색깔 칸 6개가 늘 같은 순서로 서요. '
                '앞에 무엇이 오느냐(Can, Do, What, How…)에 따라 뒤가 어떻게 바뀌는지 카드를 끼우며 익혀요.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('영어 문장 지도', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      const SentenceMapLegend(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${done.where((d) => basicsLessons.any((l) => l.id == d)).length} / ${basicsLessons.length} 완료',
                style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < basicsLessons.length; i++)
                _LessonTile(
                  index: i,
                  lesson: basicsLessons[i],
                  done: done.contains(basicsLessons[i].id),
                  next: i == nextIdx,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.index, required this.lesson, required this.done, required this.next});
  final int index;
  final Lesson lesson;
  final bool done;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = AppColors.of(context).good;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: next
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: scheme.primary, width: 2),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: done ? good.withValues(alpha: 0.18) : scheme.primaryContainer,
          foregroundColor: done ? good : scheme.onPrimaryContainer,
          child: done ? const Icon(Icons.check_rounded) : Text('${index + 1}'),
        ),
        title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(lesson.subtitle),
        trailing: next ? Chip(label: const Text('다음'), visualDensity: VisualDensity.compact) : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(index: index))),
      ),
    );
  }
}

// ---------------- 레슨 화면 ----------------

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.index});
  final int index;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _step = 0;
  final _solved = <int>{};

  Lesson get lesson => basicsLessons[widget.index];
  int get _total => lesson.concepts.length + lesson.drills.length + 1;

  bool get _canNext {
    final d = _step - lesson.concepts.length;
    if (d < 0) return true;
    if (d < lesson.drills.length) return _solved.contains(_step);
    return true;
  }

  void _next() {
    Speaker.instance.stop().catchError((_) {});
    if (_step == _total - 1) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step++);
    if (_step == _total - 1) AppState.instance.markBasicsDone(lesson.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = lesson.concepts.length;
    final Widget body;
    if (_step < c) {
      body = _ConceptView(concept: lesson.concepts[_step]);
    } else if (_step < c + lesson.drills.length) {
      final drill = lesson.drills[_step - c];
      void onSolved() => setState(() => _solved.add(_step));
      body = drill is BuildDrill
          ? BuildDrillView(key: ValueKey('b$_step'), drill: drill, onSolved: onSolved)
          : PickDrillView(key: ValueKey('p$_step'), drill: drill as PickDrill, onSolved: onSolved);
    } else {
      body = _LessonDone(lesson: lesson, hasNext: widget.index + 1 < basicsLessons.length);
    }
    final last = _step == _total - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.index + 1}. ${lesson.title}', overflow: TextOverflow.ellipsis),
        actions: const [PronToggle(), SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _total, minHeight: 4),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: body),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (_step > 0 && !last)
                    TextButton(onPressed: () => setState(() => _step--), child: const Text('이전')),
                  const Spacer(),
                  if (last && widget.index + 1 < basicsLessons.length) ...[
                    OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('목록')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => LessonScreen(index: widget.index + 1)),
                      ),
                      child: const Text('다음 레슨'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _canNext ? _next : null,
                      style: FilledButton.styleFrom(backgroundColor: _canNext ? scheme.primary : null),
                      child: Text(last ? '목록으로' : (_canNext ? '다음' : '카드를 끼워 보세요')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptView extends StatelessWidget {
  const _ConceptView({required this.concept});
  final Concept concept;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SentenceMapLegend(compact: true),
        const SizedBox(height: 18),
        Text(concept.title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(concept.body, style: text.bodyLarge?.copyWith(height: 1.5)),
        const SizedBox(height: 16),
        for (final e in concept.examples)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _say(e.en),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 6, runSpacing: 8, children: [for (final ch in e.chunks) ChunkBlock(ch)]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.en, style: englishStyle(context, size: 16)),
                              PronText(e.en),
                              Text(e.ko, style: TextStyle(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.volume_up_rounded, color: scheme.primary),
                        const SizedBox(width: 4),
                        SpeakCheckButton(e.en, ko: e.ko),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 조립 문제: 칸 순서대로 조각 카드를 눌러 끼운다.
class BuildDrillView extends StatefulWidget {
  const BuildDrillView({super.key, required this.drill, required this.onSolved});
  final BuildDrill drill;
  final VoidCallback onSolved;

  @override
  State<BuildDrillView> createState() => _BuildDrillViewState();
}

class _BuildDrillViewState extends State<BuildDrillView> {
  late final List<Chunk> _pool;
  final _used = <int>{};
  int _filled = 0;
  String? _message;
  bool _messageBad = false;
  int? _hint;

  BuildDrill get d => widget.drill;
  bool get _done => _filled == d.answer.length;

  @override
  void initState() {
    super.initState();
    _pool = [...d.answer, ...d.wrong]..shuffle(math.Random(d.ko.hashCode));
  }

  void _tap(int i) {
    if (_done || _used.contains(i)) return;
    final c = _pool[i];
    final want = d.answer[_filled];
    setState(() {
      _hint = null;
      if (c.text == want.text && c.tip == null) {
        _used.add(i);
        _filled++;
        _message = null;
        if (_done) {
          _say(d.en);
          widget.onSolved();
        }
      } else if (c.tip != null) {
        _message = c.tip;
        _messageBad = true;
      } else if (d.answer.skip(_filled).any((a) => a.text == c.text)) {
        _message = '‘${c.text}’는 맞는 조각이에요. 그런데 지금은 ‘${want.slot.label}’ 자리예요.';
        _messageBad = false;
      } else {
        _message = '지금은 ‘${want.slot.label}’ 자리예요.';
        _messageBad = true;
      }
    });
  }

  void _showHint() {
    final want = d.answer[_filled];
    final i = [
      for (var k = 0; k < _pool.length; k++) k,
    ].firstWhere((k) => !_used.contains(k) && _pool[k].text == want.text && _pool[k].tip == null);
    setState(() {
      _hint = i;
      _message = '‘${want.slot.label}’ 자리: ${want.slot.help}';
      _messageBad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final good = AppColors.of(context).good;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          d.from != null ? '바꿔 말해 보세요' : '영어로 조립해 보세요',
          style: text.labelLarge?.copyWith(color: scheme.tertiary),
        ),
        const SizedBox(height: 6),
        if (d.from != null) ...[
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [for (final ch in d.from!) ChunkBlock(ch, showLabel: true)],
          ),
          const SizedBox(height: 4),
          Text(joinChunks(d.from!, d.fromEnd), style: TextStyle(color: scheme.onSurfaceVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.arrow_downward_rounded, color: scheme.outline),
          ),
        ],
        Text(d.ko, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        // 칸들
        Wrap(
          spacing: 6,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (var k = 0; k < d.answer.length; k++)
              k < _filled
                  ? ChunkBlock(d.answer[k], big: true)
                  : _EmptySlot(slot: d.answer[k].slot, active: k == _filled),
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text(d.end, style: englishStyle(context, size: 22)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_message != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: (_messageBad ? scheme.error : scheme.primary).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_message!, style: text.bodyMedium),
          ),
        if (!_done) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _pool.length; i++)
                if (!_used.contains(i))
                  ActionChip(
                    label: Text(_pool[i].text, style: englishStyle(context, size: 17)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    side: BorderSide(
                      color: _hint == i ? scheme.primary : scheme.outlineVariant,
                      width: _hint == i ? 2.5 : 1,
                    ),
                    onPressed: () => _tap(i),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
            label: const Text('힌트'),
            onPressed: _showHint,
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: good.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: good),
                    const SizedBox(width: 6),
                    Text(
                      '맞았어요!',
                      style: text.titleMedium?.copyWith(color: good, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(d.en, style: englishStyle(context, size: 20).copyWith(fontWeight: FontWeight.w600)),
                PronText(d.en, size: 15),
                if (d.note != null) ...[
                  const SizedBox(height: 6),
                  Text('📌 ${d.note}', style: text.bodyMedium),
                ],
                const SizedBox(height: 10),
                Text('소리 내서 말해 보세요', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ListenSpeakButtons(d.en, ko: d.ko),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.slot, required this.active});
  final Slot slot;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = slotColor(slot);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 42,
          decoration: BoxDecoration(
            color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(
              color: c.withValues(alpha: active ? 0.9 : 0.4),
              width: active ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: active ? Icon(Icons.touch_app_rounded, size: 18, color: c) : null,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            slot.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
          ),
        ),
      ],
    );
  }
}

/// 고르기 문제: 맨 앞 빈칸에 들어갈 말 고르기.
class PickDrillView extends StatefulWidget {
  const PickDrillView({super.key, required this.drill, required this.onSolved});
  final PickDrill drill;
  final VoidCallback onSolved;

  @override
  State<PickDrillView> createState() => _PickDrillViewState();
}

class _PickDrillViewState extends State<PickDrillView> {
  String? _picked;
  bool _solved = false;

  PickDrill get d => widget.drill;

  void _pick(String o) {
    if (_solved) return;
    setState(() {
      _picked = o;
      if (o == d.answer) {
        _solved = true;
        _say(d.en);
        widget.onSolved();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final good = AppColors.of(context).good;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('맨 앞에 올 말을 골라 보세요', style: text.labelLarge?.copyWith(color: scheme.tertiary)),
        const SizedBox(height: 6),
        Text(d.ko, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _solved ? d.answer : '____',
                style: TextStyle(color: _solved ? good : scheme.primary, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: ' ${d.rest}'),
            ],
          ),
          style: englishStyle(context, size: 24),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in d.options)
              ChoiceChip(
                label: Text(o, style: englishStyle(context, size: 18)),
                selected: _picked == o,
                selectedColor: o == d.answer
                    ? good.withValues(alpha: 0.2)
                    : scheme.error.withValues(alpha: 0.15),
                onSelected: (_) => _pick(o),
              ),
          ],
        ),
        if (_picked != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_solved ? good : scheme.error).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_solved ? '맞았어요! ${d.why}' : '다시 생각해 봐요. ${d.why}', style: text.bodyMedium),
          ),
        ],
        if (_solved) ...[
          const SizedBox(height: 10),
          PronText(d.en, size: 15),
          const SizedBox(height: 8),
          ListenSpeakButtons(d.en, ko: d.ko),
        ],
      ],
    );
  }
}

class _LessonDone extends StatelessWidget {
  const _LessonDone({required this.lesson, required this.hasNext});
  final Lesson lesson;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final good = AppColors.of(context).good;
    final notes = [
      for (final d in lesson.drills)
        if (d is BuildDrill && d.note != null) d.note!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Icon(Icons.emoji_events_rounded, size: 56, color: good),
        const SizedBox(height: 8),
        Text('‘${lesson.title}’ 완료!', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Text('오늘 익힌 것', style: text.titleMedium),
        const SizedBox(height: 6),
        for (final c in lesson.concepts) Text('• ${c.title}', style: text.bodyLarge),
        for (final n in notes) Text('• $n', style: text.bodyLarge),
      ],
    );
  }
}
