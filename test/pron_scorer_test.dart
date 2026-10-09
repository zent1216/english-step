import 'dart:math' as math;
import 'dart:typed_data';

import 'package:english_step/pronunciation.dart';
import 'package:english_step/speech/fbank.dart';
import 'package:english_step/speech/ort.dart';
import 'package:english_step/speech/pron_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fbank는 kaldi-native-fbank와 같은 값', () {
    // 파이썬 kaldi_native_fbank로 구한 값(0.5초, 440Hz + 1500Hz)
    final x = Float32List.fromList([
      for (var i = 0; i < 8000; i++)
        0.3 * math.sin(2 * math.pi * 440 * i / 16000) + 0.1 * math.sin(2 * math.pi * 1500 * i / 16000)
    ]);
    final f = fbank(x);
    expect(f.length ~/ melBins, 50);
    const want10 = [8.7246, 15.202, 12.4115, 10.4575, -3.1317];
    const want0 = [15.3607, 20.0303, 19.2203, 19.9786, 12.0251];
    const bins = [0, 10, 20, 40, 79];
    for (var k = 0; k < bins.length; k++) {
      expect(f[10 * melBins + bins[k]], closeTo(want10[k], 0.01));
      expect(f[0 * melBins + bins[k]], closeTo(want0[k], 0.01));
    }
  });

  group('강제 정렬 채점', () {
    // 어휘: ▁hi(0) ▁la(1) tte(2) ▁no(3) thing(4) blank(5)
    final vocab = CtcVocab(['▁hi', '▁la', 'tte', '▁no', 'thing', '<blk>']);
    Matrix frames(List<int> best) {
      final v = vocab.pieces.length;
      final d = Float32List(best.length * v);
      for (var t = 0; t < best.length; t++) {
        for (var k = 0; k < v; k++) {
          d[t * v + k] = k == best[t] ? math.log(0.9) : math.log(0.1 / (v - 1));
        }
      }
      return Matrix(best.length, v, d);
    }

    test('정답대로 말하면 0에 가깝다', () {
      final g = wordGops(frames([5, 0, 5, 1, 2, 5]), vocab, 'Hi, latte!');
      expect(g[0], closeTo(0, 0.01));
      expect(g[1], closeTo(0, 0.01));
    });
    test('다른 말이면 크게 낮다(latte 자리에 nothing)', () {
      final g = wordGops(frames([5, 0, 5, 3, 4, 5]), vocab, 'Hi, latte!');
      expect(g[0], closeTo(0, 0.01));
      expect(g[1]!, lessThan(gopClose));
    });
  });

  group('받아쓰기 + 발음 채점 합치기', () {
    test('받아쓰기가 nothing이어도 소리가 맞으면 맞음', () {
      final r = checkSpeech('I want a latte.', 'I want a nothing');
      expect(r.words[3].mark, WordMark.miss);
      final r2 = applyGops(r, [0.0, 0.0, 0.0, -0.4]);
      expect(r2.words[3].mark, WordMark.ok);
      expect(r2.words[3].byAcoustic, isTrue);
      expect(r2.score, 100);
      expect(r2.rescued, 1);
    });
    test('소리가 조금 다르면 비슷해요, 많이 다르면 그대로 틀림', () {
      final r = checkSpeech('I want a latte.', 'I want a nothing');
      expect(applyGops(r, [0, 0, 0, -2.5]).words[3].mark, WordMark.close);
      expect(applyGops(r, [0, 0, 0, -6.0]).words[3].mark, WordMark.miss);
    });
    test('받아쓰기로 맞은 단어는 발음 점수가 낮아도 그대로', () {
      final r = checkSpeech('I want a latte.', 'I want a latte');
      expect(applyGops(r, [-9, -9, -9, -9]).score, 100);
    });
    test('아무 말도 안 했으면 올려주지 않는다', () {
      final r = checkSpeech('I want a latte.', '');
      expect(applyGops(r, [0, 0, 0, 0]).score, 0);
    });
  });
}
