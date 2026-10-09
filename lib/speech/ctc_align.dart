/// 발음 채점 핵심(순수 Dart): 음성 → CTC 확률 → 정답 문장 강제 정렬 → 단어별 GOP.
/// Flutter 없이 돌아가서 클라우드에서 TTS 음성으로 시험할 수 있다. 설명은 pron_scorer.dart.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../models.dart';
import 'fbank.dart';
import 'ort.dart';

/// 단어별 발음 점수(GOP). 0에 가까울수록 정답대로, 음수가 클수록 다른 소리.
/// 원문 단어(문장부호 포함, checkSpeech의 단어 나누기와 같음)마다 하나, 글자가 없는 단어는 null.
typedef WordGops = List<double?>;

/// 음성 → CTC 로그 확률 [프레임 × 어휘].
Matrix ctcLogProbs(OrtCtcSession session, Float32List samples) {
  // 너무 짧으면 모델이 못 돌아서 앞뒤에 무음을 붙인다.
  var s = samples;
  if (s.length < 8000) {
    final pad = Float32List(8000);
    pad.setRange((8000 - s.length) ~/ 2, (8000 - s.length) ~/ 2 + s.length, s);
    s = pad;
  }
  final feats = fbank(s);
  final frames = feats.length ~/ melBins;
  return session.run(normalizeTransposed(feats, frames), melBins, frames);
}

/// CTC 어휘(SentencePiece 조각). 마지막이 blank.
class CtcVocab {
  CtcVocab(this.pieces) : blank = pieces.length - 1 {
    for (var i = 0; i < pieces.length - 1; i++) {
      lower.putIfAbsent(pieces[i].toLowerCase(), () => []).add(i);
    }
  }
  factory CtcVocab.fromLines(List<String> lines) => CtcVocab([
    for (final l in lines)
      if (l.trim().isNotEmpty) l.trim().split(RegExp(r'\s+')).first,
  ]);

  final List<String> pieces;
  final int blank;
  final Map<String, List<int>> lower = {};
}

class _Arc {
  _Arc(this.start, this.end, this.ids);
  final int start, end;
  final List<int> ids;
}

/// 정답 문장의 단어별 GOP. [lp]는 [ctcLogProbs] 결과.
WordGops wordGops(Matrix lp, CtcVocab vocab, String target) {
  final display = plainText(target).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // 글자열(소문자 영문만)과 글자별 원문 단어 번호
  final chars = StringBuffer();
  final owner = <int>[];
  for (var d = 0; d < display.length; d++) {
    for (final c in display[d].toLowerCase().split('')) {
      if (RegExp('[a-z]').hasMatch(c)) {
        chars.write(c);
        owner.add(d);
      }
    }
  }
  final s = chars.toString();
  final n = s.length;
  final result = List<double?>.filled(display.length, null);
  if (n == 0 || lp.rows == 0) return result;

  // 글자 구간을 덮는 토큰 아크(단어 경계 표시 "▁"는 어디든 붙어도 됨)
  final arcs = <_Arc>[];
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j <= math.min(n, i + 12); j++) {
      final sub = s.substring(i, j);
      for (final k in [sub, '▁$sub']) {
        final ids = vocab.lower[k];
        if (ids != null) arcs.add(_Arc(i, j, ids));
      }
    }
  }
  final T = lp.rows, A = arcs.length, V = lp.cols;
  final blank = vocab.blank;
  // 아크별 프레임 점수(같은 글자 조각의 대소문자 변형 중 최대)
  final ascore = Float64List(T * A);
  for (var t = 0; t < T; t++) {
    for (var a = 0; a < A; a++) {
      var best = -1e30;
      for (final id in arcs[a].ids) {
        final v = lp.data[t * V + id];
        if (v > best) best = v;
      }
      ascore[t * A + a] = best;
    }
  }
  final startsAt = List.generate(n + 1, (_) => <int>[]);
  final endsAt = List.generate(n + 1, (_) => <int>[]);
  for (var a = 0; a < A; a++) {
    startsAt[arcs[a].start].add(a);
    endsAt[arcs[a].end].add(a);
  }

  const neg = -1e30;
  var B = Float64List(n + 1)..fillRange(0, n + 1, neg);
  var X = Float64List(A)..fillRange(0, A, neg);
  // 역추적: 음수 = blank(-1-i), 0 이상 = 아크
  final bpB = Int32List(T * (n + 1));
  final bpX = Int32List(T * A);
  B[0] = lp.data[blank];
  for (final a in startsAt[0]) {
    X[a] = ascore[a];
  }
  for (var t = 1; t < T; t++) {
    final nB = Float64List(n + 1);
    final nX = Float64List(A);
    final endBest = Float64List(n + 1)..fillRange(0, n + 1, neg);
    final endArg = Int32List(n + 1)..fillRange(0, n + 1, -1);
    for (var i = 0; i <= n; i++) {
      for (final a in endsAt[i]) {
        if (X[a] > endBest[i]) {
          endBest[i] = X[a];
          endArg[i] = a;
        }
      }
    }
    final bl = lp.data[t * V + blank];
    for (var i = 0; i <= n; i++) {
      var best = B[i];
      var src = -1 - i;
      if (endBest[i] > best) {
        best = endBest[i];
        src = endArg[i];
      }
      nB[i] = best + bl;
      bpB[t * (n + 1) + i] = src;
    }
    for (var a = 0; a < A; a++) {
      final i = arcs[a].start;
      var best = X[a];
      var src = a;
      if (B[i] > best) {
        best = B[i];
        src = -1 - i;
      }
      // 다른 아크에서 바로 넘어오기(같은 아크로 다시 시작하려면 blank를 거쳐야 함)
      if (endBest[i] > best && endArg[i] != a) {
        best = endBest[i];
        src = endArg[i];
      } else if (endArg[i] == a) {
        for (final b in endsAt[i]) {
          if (b != a && X[b] > best) {
            best = X[b];
            src = b;
          }
        }
      }
      nX[a] = best + ascore[t * A + a];
      bpX[t * A + a] = src;
    }
    B = nB;
    X = nX;
  }
  var cur = -1 - n;
  var bestEnd = B[n];
  for (final a in endsAt[n]) {
    if (X[a] > bestEnd) {
      bestEnd = X[a];
      cur = a;
    }
  }
  if (bestEnd <= neg / 2) return result;
  final path = Int32List(T);
  for (var t = T - 1; t >= 0; t--) {
    path[t] = cur;
    cur = cur < 0 ? bpB[t * (n + 1) + (-1 - cur)] : bpX[t * A + cur];
  }

  // 단어별: 그 단어 글자에 정렬된 프레임 구간에서 (정답 맞추기 점수 - 가장 잘 맞는 점수) / 프레임 수
  final first = List<int>.filled(display.length, -1);
  final last = List<int>.filled(display.length, -1);
  for (var t = 0; t < T; t++) {
    if (path[t] < 0) continue;
    final d = owner[arcs[path[t]].start];
    if (first[d] < 0) first[d] = t;
    last[d] = t;
  }
  for (var d = 0; d < display.length; d++) {
    if (!owner.contains(d)) continue;
    if (first[d] < 0) {
      result[d] = -99;
      continue;
    }
    var forced = 0.0, free = 0.0;
    for (var t = first[d]; t <= last[d]; t++) {
      final p = path[t];
      forced += p < 0 ? lp.data[t * V + blank] : ascore[t * A + p];
      var m = -1e30;
      for (var v = 0; v < V; v++) {
        final x = lp.data[t * V + v];
        if (x > m) m = x;
      }
      free += m;
    }
    result[d] = (forced - free) / (last[d] - first[d] + 1);
  }
  return result;
}
