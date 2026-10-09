/// 따라 말하기: 음성 인식이 알아들은 문장을 원문과 단어 단위로 비교한다.
///
/// 발음기호 단위 채점이 아니라 "원어민(음성 인식)이 알아듣는가"를 본다. 그래서 음성 인식의 **표기 차이**는
/// 틀린 것으로 치지 않는다(관대한 채점):
/// - 같은 소리 다른 철자: to/too/two, for/four, there/their, no/know …
/// - 축약형과 풀어쓴 말: I'm = I am, don't = do not …
/// - 숫자와 영어 숫자: 4 = four
/// - 거의 같은 단어(walk/walks, color/colour 등 글자가 조금 다름)는 "비슷해요"로 부분 점수
library;

import 'models.dart';

enum WordMark { ok, close, miss }

class WordCheck {
  const WordCheck(this.word, {required this.mark, this.counted = true, this.byAcoustic = false});
  final String word; // 화면에 보일 원문 단어(문장부호 포함)
  final WordMark mark;
  final bool counted; // 점수에 포함되는 단어인지(문장부호만 있는 토큰은 제외)
  final bool byAcoustic; // 받아쓰기는 달랐지만 소리를 직접 비교해(발음 채점) 올려준 단어

  bool get ok => mark == WordMark.ok;
}

class SpeakResult {
  const SpeakResult(this.words, this.heard);
  final List<WordCheck> words;
  final String heard;

  int get total => words.where((w) => w.counted).length;
  int get rescued => words.where((w) => w.counted && w.byAcoustic).length;
  int get matched => words.where((w) => w.counted && w.mark == WordMark.ok).length;
  int get close => words.where((w) => w.counted && w.mark == WordMark.close).length;

  /// 0~100. 비슷한 단어는 0.7점.
  int get score => total == 0 ? 0 : ((matched + close * 0.7) * 100 / total).round();

  String get message {
    if (heard.trim().isEmpty) return '목소리가 들리지 않았어요. 마이크 버튼을 누르고 말해보세요.';
    if (score >= 85) return '완벽해요! 원어민도 잘 알아들어요.';
    if (score >= 65) return '좋아요! 빨간 단어만 한 번 더 연습해봐요.';
    if (score >= 40) return '절반 넘게 전달됐어요. 원어민 소리를 한 번 더 듣고 따라 해봐요.';
    return '원어민 소리를 듣고, 편한 속도로 이어서 말해봐요.';
  }
}

/// 비교용 정규화: 소문자, 영문·숫자만 남김. "I'm" → "im", "Hi!" → "hi"
String normalizeWord(String w) => w.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), '');

// 같은 소리로 들리는 단어는 하나의 대표 표기로 모은다.
const _homophones = <String, String>{
  'too': 'to', 'two': 'to', '2': 'to',
  'four': 'for', '4': 'for', 'fore': 'for',
  'their': 'there', 'theyre': 'there',
  'youre': 'your',
  'its': 'it', // it's/its
  'know': 'no',
  'write': 'right', 'rite': 'right',
  'here': 'hear',
  'sea': 'see',
  'buy': 'by', 'bye': 'by',
  'won': 'one', '1': 'one',
  'ate': 'eight', '8': 'eight',
  'knew': 'new',
  'whether': 'weather',
  'weight': 'wait',
  'sew': 'so',
  'rode': 'road',
  'meat': 'meet',
  'weak': 'week',
  'hour': 'our',
  'eye': 'i',
  'whole': 'hole',
  'wood': 'would',
  'peace': 'piece',
  'flour': 'flower',
  'mail': 'male',
  'red': 'read',
  'sun': 'son',
  'tail': 'tale',
  'pair': 'pear', 'pare': 'pear',
  'allowed': 'aloud',
  'ok': 'okay',
  'gonna': 'going', 'wanna': 'want',
  'mr': 'mister', 'mrs': 'missus',
  '0': 'zero', '3': 'three', '5': 'five', '6': 'six', '7': 'seven', '9': 'nine', '10': 'ten',
  '11': 'eleven', '12': 'twelve', '20': 'twenty', '30': 'thirty', '100': 'hundred',
};

// 축약형 → 풀어쓴 말. 원문과 음성 인식 결과 **양쪽 다** 풀어쓴 형태로 맞춘 뒤 비교한다
// ("I'm" = "I am", "That's" = "that is"). 양쪽에 똑같이 적용하므로 well/were 같은 단어도 안전하다.
const _contractions = <String, String>{
  'im': 'i am',
  'youre': 'you are',
  'were': 'we are',
  'theyre': 'they are',
  'hes': 'he is',
  'shes': 'she is',
  'its': 'it is',
  'thats': 'that is',
  'theres': 'there is',
  'whats': 'what is',
  'whos': 'who is',
  'heres': 'here is',
  'ill': 'i will',
  'youll': 'you will',
  'well': 'we will',
  'theyll': 'they will',
  'hell': 'he will',
  'shell': 'she will',
  'itll': 'it will',
  'ive': 'i have',
  'youve': 'you have',
  'weve': 'we have',
  'theyve': 'they have',
  'id': 'i would',
  'youd': 'you would',
  'wed': 'we would',
  'theyd': 'they would',
  'dont': 'do not',
  'doesnt': 'does not',
  'didnt': 'did not',
  'isnt': 'is not',
  'arent': 'are not',
  'wasnt': 'was not',
  'werent': 'were not',
  'cant': 'can not',
  'wont': 'will not',
  'wouldnt': 'would not',
  'couldnt': 'could not',
  'shouldnt': 'should not',
  'havent': 'have not',
  'hasnt': 'has not',
  'lets': 'let us',
  'cannot': 'can not',
};

String _canon(String key) => _homophones[key] ?? key;

/// 정규화한 단어 하나를 비교용 단어들로(축약형이면 2개).
List<String> _expand(String key) =>
    key.isEmpty ? const [] : (_contractions[key]?.split(' ') ?? [key]);

int _editDistance(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// 소리 열쇠: 모음을 빼고 비슷한 소리는 하나로 모은다.
/// - 철자 묶음: ph→f, gh(묵음), ck→k, c(e/i/y 앞)→s, 나머지 c·q→k, x→ks
/// - 유성·무성은 같은 소리로(b=p, d=t, g=k, v=f, z=s). 미국식 latte는 "라디"처럼 들려서 t/d를 구분하지 않는다.
/// 음성 인식이 모음과 단어 경계를 잘 헷갈려서(meet→mate, latte→"la tay") 열쇠가 같으면 "비슷해요"로 본다.
String consonantSkeleton(String w) {
  var x = w.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  x = x
      .replaceAll('ph', 'f')
      .replaceAll('gh', '')
      .replaceAll('ck', 'k')
      .replaceAll(RegExp('c(?=[eiy])'), 's')
      .replaceAll(RegExp('[cq]'), 'k')
      .replaceAll('x', 'ks')
      .replaceAll('b', 'p')
      .replaceAll('d', 't')
      .replaceAll('g', 'k')
      .replaceAll('v', 'f')
      .replaceAll('z', 's');
  x = x.replaceAll(RegExp('[aeiouyhw]'), '');
  return x.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
}

/// 두 단어가 얼마나 맞는지: 1 = 같음, 0.7 = 비슷함, 0 = 다름.
double wordMatch(String target, String heard) {
  if (target.isEmpty || heard.isEmpty) return 0;
  if (target == heard || _canon(target) == _canon(heard)) return 1;
  final longer = target.length > heard.length ? target.length : heard.length;
  if (longer < 3) return 0; // a/an, in/on 같은 짧은 단어는 정확해야 한다
  final sk = consonantSkeleton(target);
  if (target.length >= 3 && sk.isNotEmpty && sk == consonantSkeleton(heard)) return 0.7;
  final sim = 1 - _editDistance(target, heard) / longer;
  return sim >= 0.7 ? 0.7 : 0;
}

/// 여러 단어를 이어 붙여 비교(단어 경계가 달라진 경우: latte ↔ "la tay", "an iced" ↔ "a nice").
/// [t]·[h]는 이어 붙일 원문 단어들과 들은 단어들. 그중 한 쌍이라도 그대로 맞으면 경계 문제가 아니므로 0.
/// 소리 열쇠가 같거나 글자가 70% 이상 같으면 0.7(이어 붙인 글자가 완전히 같으면 1).
double _spanMatch(List<String> t, List<String> h) {
  for (final a in t) {
    for (final b in h) {
      if (wordMatch(a, b) >= 1) return 0;
    }
  }
  final target = t.join(), heard = h.join();
  if (target.length < 3 || heard.isEmpty) return 0;
  if (target == heard) return 1;
  final k = consonantSkeleton(target);
  if (k.isNotEmpty && k == consonantSkeleton(heard)) return 0.7;
  final longer = target.length > heard.length ? target.length : heard.length;
  return 1 - _editDistance(target, heard) / longer >= 0.7 ? 0.7 : 0;
}

/// [target]은 `[표현|뜻]` 표시가 있어도 된다.
SpeakResult checkSpeech(String target, String heard) {
  final display = plainText(target).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // 원문 단어를 비교용 단어로 풀고, 각 단어가 어느 원문 단어에서 왔는지 기억한다.
  final keys = <String>[];
  final owner = <int>[];
  for (var d = 0; d < display.length; d++) {
    for (final k in _expand(normalizeWord(display[d]))) {
      keys.add(k);
      owner.add(d);
    }
  }
  final hk = [for (final w in heard.split(RegExp(r'\s+'))) ..._expand(normalizeWord(w))];

  // 가중 정렬: 순서를 지키면서 맞은 정도(1/0.7)의 합이 가장 큰 짝을 찾는다.
  // 한 단어↔한 단어 외에, 단어 경계가 달라진 경우(원문 1↔들은 2, 원문 2↔들은 1, 2↔2)도 이어 붙여 비교한다.
  final n = keys.length, m = hk.length;
  final dp = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  // 각 칸에서 고른 이동: (원문 몇 개, 들은 말 몇 개, 단어당 점수)
  final pick = List.generate(n + 1, (_) => List<(int, int, double)>.filled(m + 1, (0, 0, 0)));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      var best = dp[i + 1][j];
      var choice = (1, 0, 0.0);
      if (dp[i][j + 1] > best) {
        best = dp[i][j + 1];
        choice = (0, 1, 0.0);
      }
      void tryMove(int di, int dj, double s) {
        if (s <= 0) return;
        final v = dp[i + di][j + dj] + s * di;
        if (v > best + 1e-9) {
          best = v;
          choice = (di, dj, s);
        }
      }

      tryMove(1, 1, wordMatch(keys[i], hk[j]));
      if (j + 1 < m) tryMove(1, 2, _spanMatch([keys[i]], [hk[j], hk[j + 1]]));
      if (i + 1 < n) tryMove(2, 1, _spanMatch([keys[i], keys[i + 1]], [hk[j]]));
      if (i + 1 < n && j + 1 < m) {
        // 경계가 실제로 옮겨진 경우만(같은 자리에서 끊기면 1↔1 비교와 같다)
        if (keys[i].length != hk[j].length) {
          tryMove(2, 2, _spanMatch([keys[i], keys[i + 1]], [hk[j], hk[j + 1]]));
        }
      }
      dp[i][j] = best;
      pick[i][j] = choice;
    }
  }
  final got = List<double>.filled(n, 0);
  var i = 0, j = 0;
  while (i < n && j < m) {
    final (di, dj, s) = pick[i][j];
    for (var k = 0; k < di; k++) {
      got[i + k] = s;
    }
    i += di;
    j += dj;
  }

  // 원문 단어별로 모은다: 전부 맞으면 ok, 일부라도 맞으면 close, 아니면 miss.
  return SpeakResult(
    [
      for (var d = 0; d < display.length; d++)
        () {
          final parts = [for (var k = 0; k < n; k++) if (owner[k] == d) got[k]];
          if (parts.isEmpty) return WordCheck(display[d], mark: WordMark.miss, counted: false);
          final mark = parts.every((g) => g >= 1)
              ? WordMark.ok
              : parts.any((g) => g > 0)
                  ? WordMark.close
                  : WordMark.miss;
          return WordCheck(display[d], mark: mark);
        }(),
    ],
    heard,
  );
}

/// 발음 채점(GOP) 기준: 이 값 이상이면 "맞음", [gopClose] 이상이면 "비슷해요". (TTS 6개 목소리로 맞춤)
const gopOk = -1.5;
const gopClose = -3.5;

/// 받아쓰기 결과 [r]에 단어별 발음 점수 [gops]를 더한다. 받아쓰기가 틀렸어도 소리가 정답과 맞으면 올려준다.
/// 받아쓰기로 이미 맞은 단어는 그대로 둔다(발음 채점은 "구제"만 한다).
SpeakResult applyGops(SpeakResult r, List<double?>? gops) {
  if (gops == null || gops.length != r.words.length || r.heard.trim().isEmpty) return r;
  return SpeakResult(
    [
      for (var i = 0; i < r.words.length; i++)
        () {
          final w = r.words[i];
          final g = gops[i];
          if (!w.counted || w.ok || g == null) return w;
          if (g >= gopOk) return WordCheck(w.word, mark: WordMark.ok, byAcoustic: true);
          if (g >= gopClose && w.mark == WordMark.miss) {
            return WordCheck(w.word, mark: WordMark.close, byAcoustic: true);
          }
          return w;
        }(),
    ],
    r.heard,
  );
}
