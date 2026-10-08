/// 앱 전체에서 쓰는 데이터 모델.
///
/// 문장 안의 `[표현|뜻]` 표시는 학습 포인트(누르면 뜻이 나오는 부분)다.
library;

final _markRe = RegExp(r'\[([^|\]]+)\|([^\]]+)\]');

/// 문장을 일반 텍스트 조각과 학습 포인트 조각으로 나눈다.
List<Segment> parseMarked(String text) {
  final out = <Segment>[];
  var last = 0;
  for (final m in _markRe.allMatches(text)) {
    if (m.start > last) out.add(Segment(text.substring(last, m.start)));
    out.add(Segment(m.group(1)!, gloss: m.group(2)));
    last = m.end;
  }
  if (last < text.length) out.add(Segment(text.substring(last)));
  return out;
}

/// `[표현|뜻]` 표시를 지운 순수 문장.
String plainText(String text) => text.replaceAllMapped(_markRe, (m) => m.group(1)!);

class Segment {
  const Segment(this.text, {this.gloss});
  final String text;
  final String? gloss;
  bool get isMarked => gloss != null;
}

class Sentence {
  const Sentence(this.en, this.ko);
  final String en;
  final String ko;
}

class Quiz {
  const Quiz(this.question, this.options, this.answer);
  final String question;
  final List<String> options;
  final int answer;
}

class Story {
  const Story({
    required this.id,
    required this.level,
    required this.levelName,
    required this.title,
    required this.titleKo,
    required this.keyExpression,
    required this.keyExpressionKo,
    required this.sentences,
    required this.quiz,
  });
  final String id;
  final int level;
  final String levelName;
  final String title;
  final String titleKo;
  final String keyExpression;
  final String keyExpressionKo;
  final List<Sentence> sentences;
  final Quiz quiz;
}

class LyricLine {
  LyricLine({required this.t, required this.en, this.ko = ''});
  double t; // 이 소절이 시작되는 시각(초)
  final String en;
  final String ko;

  Map<String, dynamic> toJson() => {'t': t, 'en': en, 'ko': ko};
  factory LyricLine.fromJson(Map<String, dynamic> j) => LyricLine(
        t: (j['t'] as num).toDouble(),
        en: j['en'] as String,
        ko: (j['ko'] as String?) ?? '',
      );
}

class Song {
  Song({
    required this.id,
    required this.title,
    required this.lines,
    this.youtubeId = '',
    this.end = 0,
    this.synced = false,
  });
  final String id;
  String title;
  String youtubeId;
  List<LyricLine> lines;
  double end; // 음원이 없을 때 노래가 끝나는 시각(초)
  bool synced; // 사용자가 타이밍을 직접 맞췄는지

  bool get isDemo => id == 'demo';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'youtubeId': youtubeId,
        'end': end,
        'synced': synced,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        title: j['title'] as String,
        youtubeId: (j['youtubeId'] as String?) ?? '',
        end: (j['end'] as num?)?.toDouble() ?? 0,
        synced: (j['synced'] as bool?) ?? false,
        lines: (j['lines'] as List)
            .map((e) => LyricLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// 단어장 항목. [box]가 클수록 잘 아는 표현이라 더 늦게 다시 나온다.
class VocabItem {
  VocabItem({
    required this.word,
    required this.gloss,
    this.context = '',
    this.box = 0,
    int? dueAt,
  }) : dueAt = dueAt ?? 0;
  final String word;
  final String gloss;
  final String context;
  int box;
  int dueAt; // 다음 복습 시각(ms since epoch)

  bool isDue(DateTime now) => dueAt <= now.millisecondsSinceEpoch;

  Map<String, dynamic> toJson() =>
      {'w': word, 'g': gloss, 'c': context, 'b': box, 'd': dueAt};
  factory VocabItem.fromJson(Map<String, dynamic> j) => VocabItem(
        word: j['w'] as String,
        gloss: j['g'] as String,
        context: (j['c'] as String?) ?? '',
        box: (j['b'] as num?)?.toInt() ?? 0,
        dueAt: (j['d'] as num?)?.toInt() ?? 0,
      );
}

/// 유튜브 주소(또는 11자리 영상 ID)에서 영상 ID를 뽑는다. 못 찾으면 빈 문자열.
String parseYoutubeId(String input) {
  final s = input.trim();
  if (RegExp(r'^[\w-]{11}$').hasMatch(s)) return s;
  final m = RegExp(r'(?:v=|youtu\.be/|shorts/|embed/|live/)([\w-]{11})').firstMatch(s);
  return m?.group(1) ?? '';
}

/// 붙여넣은 가사를 소절 목록으로 만든다. 한 줄에 한 소절, 해석은 " | " 뒤에.
List<LyricLine> parseLyrics(String raw, {double gap = 4}) {
  final rows = raw
      .split('\n')
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty)
      .toList();
  return [
    for (var i = 0; i < rows.length; i++)
      () {
        final parts = rows[i].split(RegExp(r'\s*\|\s*'));
        return LyricLine(
          t: i * gap,
          en: parts.first.replaceAll(RegExp(r'[\[\]]'), ''),
          ko: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        );
      }(),
  ];
}
