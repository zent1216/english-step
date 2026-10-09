import 'dart:math' as math;
import 'dart:typed_data';

import 'package:english_step/pronunciation.dart';
import 'package:english_step/speech/audio_prep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('채점', () {
    test('똑같이 말하면 100점, 대소문자·문장부호는 무시', () {
      final r = checkSpeech('"Hi! What can I get for you?"', 'hi what can I get for you');
      expect(r.score, 100);
      expect(r.words.every((w) => w.ok), isTrue);
    });

    test('완전히 다른 단어만 빨강', () {
      final r = checkSpeech('I fold a paper boat tonight', 'I sold a paper boat tonight');
      // fold/sold는 한 글자 차이라 "비슷해요"(부분 점수)
      expect(r.words.firstWhere((w) => w.word == 'fold').mark, WordMark.close);
      final r2 = checkSpeech('I fold a paper boat tonight', 'I make a paper boat tonight');
      expect(r2.words.firstWhere((w) => w.word == 'fold').mark, WordMark.miss);
      expect(r2.matched, 5);
    });

    test('같은 소리 다른 철자는 정답(for/four, to/two, no/know)', () {
      expect(checkSpeech('That is for you', 'that is four you').score, 100);
      expect(checkSpeech('I want to go', 'I want two go').score, 100);
      expect(checkSpeech("I don't know", "I don't no").score, 100);
    });

    test('축약형과 풀어쓴 말은 같다', () {
      expect(checkSpeech("Sorry, I'm [running late|늦어지고 있다].", 'sorry I am running late').score, 100);
      expect(checkSpeech("I don't like it", 'I do not like it').score, 100);
      expect(checkSpeech("That's four dollars.", 'that is 4 dollars').score, 100);
    });

    test('복수형·과거형처럼 조금 다른 단어는 부분 점수', () {
      final r = checkSpeech('She walks to school', 'she walk to school');
      expect(r.words[1].mark, WordMark.close);
      expect(r.score, 93); // (3 + 0.7) / 4
    });

    test('짧은 단어(a/an/in/on)는 정확해야 한다', () {
      final r = checkSpeech('It is in the box', 'it is on the box');
      expect(r.words[2].mark, WordMark.miss);
    });

    test('순서를 지키고, 더 말한 단어는 감점하지 않음', () {
      expect(checkSpeech('To go, please', 'um to go please thank you').score, 100);
      expect(checkSpeech('to go please', 'please go to').matched, 1);
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
  });

  group('받아쓰기 전 소리 다듬기', () {
    const rate = 16000;
    Float32List build(List<(double seconds, bool voice)> parts) {
      final out = <double>[];
      final rnd = math.Random(1);
      for (final (sec, voice) in parts) {
        for (var i = 0; i < (sec * rate).round(); i++) {
          out.add(voice ? 0.3 * math.sin(2 * math.pi * 220 * i / rate) : (rnd.nextDouble() - 0.5) * 0.002);
        }
      }
      return Float32List.fromList(out);
    }

    test('무음만 있으면 빈 목록', () {
      expect(prepareForAsr(build([(2, false)])), isEmpty);
    });

    test('앞뒤 무음을 자르고 긴 쉼을 줄인다', () {
      // 1초 무음 + 말 0.5초 + 2초 쉼(천천히 말함) + 말 0.5초 + 1초 무음 = 5초
      final chunks = prepareForAsr(build([(1, false), (0.5, true), (2, false), (0.5, true), (1, false)]));
      expect(chunks, hasLength(1));
      final sec = chunks.first.length / rate;
      expect(sec, lessThan(2.0)); // 말 1초 + 앞뒤 여유 + 짧은 쉼
      expect(sec, greaterThan(1.0));
    });

    test('8초가 넘으면 나눠서 받아쓴다', () {
      final parts = <(double, bool)>[];
      for (var k = 0; k < 6; k++) {
        parts..add((2, true))..add((1, false));
      }
      final chunks = prepareForAsr(build(parts));
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.length / rate, lessThanOrEqualTo(8.0));
      }
    });
  });
}
