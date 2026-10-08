import 'package:english_step/pronunciation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('똑같이 말하면 100점, 대소문자·문장부호는 무시', () {
    final r = checkSpeech('"Hi! What can I get for you?"', 'hi what can I get for you');
    expect(r.score, 100);
    expect(r.words.every((w) => w.ok), isTrue);
  });

  test('못 알아들은 단어만 표시', () {
    final r = checkSpeech('I fold a paper boat tonight', 'I hold a paper boat tonight');
    expect(r.words.where((w) => !w.ok).map((w) => w.word), ['fold']);
    expect(r.matched, 5);
    expect(r.score, 83);
  });

  test('축약형과 학습 포인트 표시를 처리', () {
    final r = checkSpeech("Sorry, I'm [running late|늦어지고 있다].", "sorry I'm running late");
    expect(r.score, 100);
    expect(r.words.map((w) => w.word).join(' '), "Sorry, I'm running late.");
  });

  test('순서를 지켜 비교하고, 더 말한 단어는 감점하지 않음', () {
    final r = checkSpeech('To go, please', 'um to go please thank you');
    expect(r.score, 100);
    final swapped = checkSpeech('to go please', 'please go to');
    expect(swapped.matched, 1);
  });

  test('아무 말도 없으면 0점과 안내 문구', () {
    final r = checkSpeech('No worries', '');
    expect(r.score, 0);
    expect(r.message, contains('목소리가 들리지 않았어요'));
  });

  test('문장부호만 있는 토큰은 점수에서 제외', () {
    final r = checkSpeech('Wait — what?', 'wait what');
    expect(r.total, 2);
    expect(r.score, 100);
  });
}
