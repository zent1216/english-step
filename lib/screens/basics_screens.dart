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

/// 색깔 조각 하나. [showLabel]이면 아래에 칸 이름과 그 칸이 답하는 질문(누르면 칸 설명창).
class ChunkBlock extends StatelessWidget {
  const ChunkBlock(this.chunk, {super.key, this.showLabel = true, this.big = false, this.highlight = false});
  final Chunk chunk;
  final bool showLabel;
  final bool big;
  final bool highlight; // 칸 설명창 예문에서 이 칸을 진하게

  @override
  Widget build(BuildContext context) {
    final c = slotColor(chunk.slot);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: big ? 12 : 10, vertical: big ? 9 : 6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: highlight ? 0.3 : 0.13),
            border: Border.all(
              color: c.withValues(alpha: highlight ? 1 : 0.7),
              width: highlight ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            chunk.text,
            style: englishStyle(context, size: big ? 20 : 17).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (showLabel)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showSlotSheet(context, chunk.slot),
            child: Padding(
              padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
              child: Column(
                children: [
                  Text(
                    chunk.slot.label,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c),
                  ),
                  Text(chunk.slot.ask, style: TextStyle(fontSize: 9.5, color: c.withValues(alpha: 0.85))),
                ],
              ),
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
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showSlotSheet(context, s),
                child: Container(
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
              ),
              if (s != Slot.m) Icon(Icons.chevron_right_rounded, size: 16, color: scheme.outline),
            ],
          ],
        ),
        if (compact)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('칸 이름을 누르면 무슨 뜻인지 설명이 나와요', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          )
        else ...[
          const SizedBox(height: 12),
          Text('칸 사전 · 누르면 자세한 설명', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          for (final s in Slot.values)
            InkWell(
              key: ValueKey('slotRow-${s.name}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => showSlotSheet(context, s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(width: 5, height: 34, color: slotColor(s)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${s.label}  ',
                              style: TextStyle(fontWeight: FontWeight.w800, color: slotColor(s), fontSize: 15),
                            ),
                            TextSpan(
                              text: '${s.ask}\n',
                              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                            ),
                            TextSpan(text: s.help),
                          ],
                        ),
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.outline),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// 칸 설명창: 이 칸이 무슨 뜻인지, 학교 문법 이름, 쉬운 설명, 예문(그 칸을 진하게).
Future<void> showSlotSheet(BuildContext context, Slot slot) {
  final c = slotColor(slot);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    border: Border.all(color: c, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    slot.label,
                    style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(slot.ask, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(slot.help, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '학교 문법 이름  ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: slot.grammar),
                ],
              ),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
              child: Text(slot.explain, style: text.bodyLarge?.copyWith(height: 1.6)),
            ),
            const SizedBox(height: 16),
            Text('예문 (누르면 들려요)', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final sample in slot.samples)
              () {
                final chunks = parseChunks(sample);
                final en = joinChunks(chunks, _endOf(chunks));
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _say(en),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 8,
                            children: [
                              for (final ch in chunks) ChunkBlock(ch, showLabel: false, highlight: ch.slot == slot),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: Text(en, style: englishStyle(context, size: 16))),
                              Icon(Icons.volume_up_rounded, size: 20, color: scheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
      );
    },
  );
}

/// 질문(의문사나 도우미로 시작, Because 제외)이면 물음표
String _endOf(List<Chunk> chunks) =>
    chunks.isNotEmpty && (chunks.first.slot == Slot.q || chunks.first.slot == Slot.h) && chunks.first.text != 'Because'
    ? '?'
    : '.';

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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(
                        text: '레슨 진행 방법\n',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            '① 튜토리얼: 규칙과 예문을 먼저 봐요(1~2쪽)\n'
                            '② 카드 문제: 카드를 끌어다 직접 문장을 만들고 "확인"\n'
                            '③ 완료: 오늘 익힌 규칙 정리',
                      ),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('영어 문장 지도', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '영어 문장은 이 6칸이 늘 이 순서로 서요. 모든 칸이 다 있어야 하는 건 아니에요(누가·한다는 거의 항상, 나머지는 필요할 때만).',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
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
        subtitle: Text('${lesson.subtitle}\n카드 문제 ${lesson.drills.length}개'),
        isThreeLine: true,
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
      body = _ConceptView(
        concept: lesson.concepts[_step],
        page: _step + 1,
        pages: c,
        drills: lesson.drills.length,
        onSkip: () => setState(() => _step = c),
      );
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
            _StageBar(
              stage: _step < c ? 0 : (_step < c + lesson.drills.length ? 1 : 2),
              tutorial: '${math.min(_step + 1, c)}/$c',
              drills: '${(_step - c + 1).clamp(0, lesson.drills.length)}/${lesson.drills.length}',
            ),
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: body),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (_step > 0 && !last) TextButton(onPressed: () => setState(() => _step--), child: const Text('이전')),
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
                      child: Text(
                        last ? '목록으로' : (_step == c - 1 ? '튜토리얼 끝 · 카드 문제 시작 ▶' : (_canNext ? '다음' : '문제를 풀어 보세요')),
                      ),
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

/// 레슨 단계 표시: ① 튜토리얼 → ② 카드 문제 → ③ 완료
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage, required this.tutorial, required this.drills});
  final int stage;
  final String tutorial;
  final String drills;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget step(int i, String label, String? count) {
      final on = i == stage, done = i < stage;
      final color = on ? scheme.primary : (done ? AppColors.of(context).good : scheme.outline);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? scheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '${done ? '✓' : '${i + 1}'} $label',
                style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: color, fontSize: 13),
              ),
              if (count != null && on) Text(count, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          step(0, '튜토리얼', tutorial),
          Icon(Icons.chevron_right_rounded, size: 16, color: scheme.outline),
          step(1, '카드 문제', drills),
          Icon(Icons.chevron_right_rounded, size: 16, color: scheme.outline),
          step(2, '완료', null),
        ],
      ),
    );
  }
}

class _ConceptView extends StatelessWidget {
  const _ConceptView({
    required this.concept,
    required this.page,
    required this.pages,
    required this.drills,
    required this.onSkip,
  });
  final Concept concept;
  final int page;
  final int pages;
  final int drills;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.school_rounded, size: 20, color: scheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '튜토리얼 $page/$pages\n',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.tertiary),
                      ),
                      TextSpan(text: '규칙을 먼저 훑어봐요. 예문은 눌러서 들을 수 있어요(끌어지지 않아요). 다 읽으면 카드 문제 $drills개를 직접 풀어요.'),
                    ],
                  ),
                  style: text.bodySmall,
                ),
              ),
              TextButton(onPressed: onSkip, child: const Text('건너뛰기')),
            ],
          ),
        ),
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

/// 조립 문제: 카드를 끌어다(또는 눌러서) 문장 줄에 놓고, 다 놓으면 "확인".
/// 칸 이름·색은 숨긴다(답을 보고 따라 하지 않게). 다 맞히면 그때 색깔 칸으로 구조를 보여준다.
class BuildDrillView extends StatefulWidget {
  const BuildDrillView({super.key, required this.drill, required this.onSolved});
  final BuildDrill drill;
  final VoidCallback onSolved;

  @override
  State<BuildDrillView> createState() => _BuildDrillViewState();
}

class _BuildDrillViewState extends State<BuildDrillView> {
  late final List<Chunk> _pool;
  final _placed = <int>[]; // 문장 줄에 놓인 카드(풀 번호) 순서
  Set<int> _wrongPos = {}; // 확인 후 틀린 자리
  bool _solved = false;
  bool _showGuide = false; // 힌트: 칸 안내 보기
  String? _message;
  bool _messageBad = false;
  int _tries = 0;
  final _cardKeys = <int, GlobalKey>{};

  BuildDrill get d => widget.drill;

  @override
  void initState() {
    super.initState();
    _pool = [...d.answer, ...d.wrong]..shuffle(math.Random(d.ko.hashCode));
  }

  void _changed(VoidCallback f) {
    if (_solved) return;
    setState(() {
      f();
      _wrongPos = {};
      _message = null;
    });
  }

  void _add(int i) => _changed(() => _placed.add(i));
  void _remove(int i) => _changed(() => _placed.remove(i));
  void _insert(int i, int at) => _changed(() {
    final from = _placed.indexOf(i);
    if (from >= 0) {
      _placed.removeAt(from);
      if (from < at) at--;
    }
    _placed.insert(at.clamp(0, _placed.length), i);
  });

  void _check() {
    final got = [for (final i in _placed) _pool[i]];
    final ok =
        got.length == d.answer.length &&
        [for (var k = 0; k < got.length; k++) got[k].tip == null && got[k].text == d.answer[k].text].every((x) => x);
    setState(() {
      _tries++;
      if (ok) {
        _solved = true;
        _message = null;
        _say(d.en);
        widget.onSolved();
        return;
      }
      _wrongPos = {
        for (var k = 0; k < got.length; k++)
          if (got[k].tip != null || k >= d.answer.length || got[k].text != d.answer[k].text) k,
      };
      _messageBad = true;
      final trap = got.where((c) => c.tip != null).toList();
      if (trap.isNotEmpty) {
        _message = '‘${trap.first.text}’: ${trap.first.tip}';
      } else if (got.length < d.answer.length) {
        final missing = d.answer.where((a) => !got.any((g) => g.text == a.text)).map((a) => a.slot.label);
        _message = '조각이 아직 남았어요. 빠진 자리: ${missing.toSet().join(', ')}';
      } else {
        final k = _wrongPos.first;
        final want = d.answer[k].slot;
        _message = '${k + 1}번째 자리에는 ‘${want.label}’이 와야 해요. (${want.help})';
      }
      if (_tries >= 2 && !_showGuide) _message = '${_message!}\n막히면 아래 ‘힌트’로 칸 안내를 볼 수 있어요.';
    });
  }

  Widget _card(BuildContext context, int i, {bool placed = false, bool dragging = false}) {
    final scheme = Theme.of(context).colorScheme;
    final pos = _placed.indexOf(i);
    final wrong = placed && _wrongPos.contains(pos);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dragging ? scheme.surfaceContainerHighest : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: wrong ? scheme.error : (placed ? scheme.primary.withValues(alpha: 0.6) : scheme.outlineVariant),
          width: wrong ? 2.5 : 1.5,
        ),
        boxShadow: dragging
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
            : null,
      ),
      child: Text(_pool[i].text, style: englishStyle(context, size: 18).copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _draggable(BuildContext context, int i, {required bool placed}) {
    return Draggable<int>(
      data: i,
      feedback: Material(color: Colors.transparent, child: _card(context, i, dragging: true)),
      childWhenDragging: Opacity(opacity: 0.3, child: _card(context, i, placed: placed)),
      child: GestureDetector(
        onTap: () => placed ? _remove(i) : _add(i),
        child: _card(context, i, placed: placed),
      ),
    );
  }

  /// 놓인 카드 위에 떨어뜨려도 끼운다: 카드 왼쪽 절반이면 앞에, 오른쪽 절반이면 뒤에.
  Widget _dropOnCard(int k) => DragTarget<int>(
    onAcceptWithDetails: (det) {
      final box = context.findRenderObject();
      final key = _cardKeys[_placed[k]];
      final cardBox = key?.currentContext?.findRenderObject() as RenderBox?;
      var at = k + 1;
      if (box != null && cardBox != null) {
        final center = cardBox.localToGlobal(cardBox.size.center(Offset.zero)).dx;
        if (det.offset.dx + 24 < center) at = k;
      }
      if (det.data != _placed[k]) _insert(det.data, at);
    },
    builder: (context, cand, _) => KeyedSubtree(
      key: _cardKeys.putIfAbsent(_placed[k], () => GlobalKey()),
      child: _draggable(context, _placed[k], placed: true),
    ),
  );

  /// 카드 사이 끼워 넣는 자리
  Widget _gap(int at) => DragTarget<int>(
    onAcceptWithDetails: (det) => _insert(det.data, at),
    builder: (context, cand, _) {
      final on = cand.isNotEmpty;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: on ? 28 : 10,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: on ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final good = AppColors.of(context).good;
    final unplaced = [
      for (var i = 0; i < _pool.length; i++)
        if (!_placed.contains(i)) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          d.from != null ? '바꿔 말해 보세요' : '카드를 끌어다 문장을 만들어 보세요',
          style: text.labelLarge?.copyWith(color: scheme.tertiary),
        ),
        const SizedBox(height: 6),
        if (d.from != null) ...[
          Wrap(spacing: 6, runSpacing: 8, children: [for (final ch in d.from!) ChunkBlock(ch)]),
          const SizedBox(height: 4),
          Text(joinChunks(d.from!, d.fromEnd), style: TextStyle(color: scheme.onSurfaceVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.arrow_downward_rounded, color: scheme.outline),
          ),
        ],
        Text(d.ko, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (_showGuide && !_solved) ...[
          Text('칸 안내', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in d.answer)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showSlotSheet(context, a.slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: slotColor(a.slot)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${a.slot.label} · ${a.slot.ask}',
                      style: TextStyle(color: slotColor(a.slot), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        // 문장 줄
        if (_solved)
          Wrap(
            spacing: 6,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final a in d.answer) ChunkBlock(a, big: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: Text(d.end, style: englishStyle(context, size: 22)),
              ),
            ],
          )
        else
          DragTarget<int>(
            onAcceptWithDetails: (det) => _insert(det.data, _placed.length),
            builder: (context, cand, _) => Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: cand.isNotEmpty
                    ? scheme.primary.withValues(alpha: 0.06)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: _placed.isEmpty
                  ? Center(
                      child: Text('여기로 카드를 끌어오거나, 카드를 눌러 넣으세요', style: TextStyle(color: scheme.onSurfaceVariant)),
                    )
                  : Wrap(
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var k = 0; k < _placed.length; k++) ...[_gap(k), _dropOnCard(k)],
                        _gap(_placed.length),
                        Text(d.end, style: englishStyle(context, size: 22)),
                      ],
                    ),
            ),
          ),
        const SizedBox(height: 12),
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
        if (!_solved) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [for (final i in unplaced) _draggable(context, i, placed: false)]),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(_showGuide ? '칸 안내 숨기기' : '힌트'),
                onPressed: () => setState(() => _showGuide = !_showGuide),
              ),
              const SizedBox(width: 8),
              if (_placed.isNotEmpty) TextButton(onPressed: () => _changed(_placed.clear), child: const Text('다시 놓기')),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('확인'),
                onPressed: _placed.isEmpty ? null : _check,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '카드를 누르면 맨 뒤에 붙고, 놓인 카드를 누르면 빠져요. 끌어서 사이에 끼울 수도 있어요.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ] else ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: good.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: good),
                    const SizedBox(width: 6),
                    Text(
                      _tries == 1 ? '한 번에 맞았어요!' : '맞았어요!',
                      style: text.titleMedium?.copyWith(color: good, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(d.en, style: englishStyle(context, size: 20).copyWith(fontWeight: FontWeight.w600)),
                PronText(d.en, size: 15),
                if (d.note != null) ...[const SizedBox(height: 6), Text('📌 ${d.note}', style: text.bodyMedium)],
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
                selectedColor: o == d.answer ? good.withValues(alpha: 0.2) : scheme.error.withValues(alpha: 0.15),
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
