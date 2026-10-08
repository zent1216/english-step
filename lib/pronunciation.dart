/// 따라 말하기: 폰 음성 인식이 알아들은 문장을 원문과 단어 단위로 비교한다.
///
/// 발음기호 단위 채점이 아니라 "원어민(음성 인식)이 알아듣는가"를 본다.
/// AI 서버 없이 기기 내장 음성 인식만으로 동작한다.
library;

import 'models.dart';

class WordCheck {
  const WordCheck(this.word, {required this.ok, this.counted = true});
  final String word; // 화면에 보일 원문 단어(문장부호 포함)
  final bool ok; // 음성 인식이 이 단어를 알아들었는지
  final bool counted; // 점수에 포함되는 단어인지(문장부호만 있는 토큰은 제외)
}

class SpeakResult {
  const SpeakResult(this.words, this.heard);
  final List<WordCheck> words;
  final String heard;

  int get total => words.where((w) => w.counted).length;
  int get matched => words.where((w) => w.counted && w.ok).length;

  /// 0~100
  int get score => total == 0 ? 0 : (matched * 100 / total).round();

  String get message {
    if (heard.trim().isEmpty) return '목소리가 들리지 않았어요. 마이크 버튼을 누르고 또박또박 말해보세요.';
    if (score >= 90) return '완벽해요! 원어민도 잘 알아들어요.';
    if (score >= 70) return '좋아요! 빨간 단어만 다시 연습해봐요.';
    if (score >= 40) return '절반 넘게 전달됐어요. 듣기를 한 번 더 하고 천천히 따라 해봐요.';
    return '천천히, 단어를 끊어서 다시 해봐요.';
  }
}

/// 비교용 정규화: 소문자, 영문·숫자만 남김. "I'm" → "im", "Hi!" → "hi"
String normalizeWord(String w) => w.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), '');

/// [target]은 `[표현|뜻]` 표시가 있어도 된다.
SpeakResult checkSpeech(String target, String heard) {
  final display = plainText(target).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final keys = display.map(normalizeWord).toList();
  final heardKeys =
      heard.split(RegExp(r'\s+')).map(normalizeWord).where((w) => w.isNotEmpty).toList();

  // 최장 공통 부분수열(LCS)로 순서를 지키며 맞은 단어를 찾는다.
  final n = keys.length, m = heardKeys.length;
  final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = keys[i].isNotEmpty && keys[i] == heardKeys[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final ok = List.filled(n, false);
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (keys[i].isNotEmpty && keys[i] == heardKeys[j]) {
      ok[i] = true;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return SpeakResult(
    [
      for (var k = 0; k < n; k++)
        WordCheck(display[k], ok: ok[k], counted: keys[k].isNotEmpty),
    ],
    heard,
  );
}
