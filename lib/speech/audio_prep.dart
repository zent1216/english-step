/// 받아쓰기 전에 녹음을 다듬는다.
///
/// - 앞뒤 무음을 잘라낸다.
/// - 천천히·띄엄띄엄 말해서 생긴 긴 공백을 짧게 줄인다(긴 무음은 인식 정확도를 떨어뜨린다).
/// - 8초가 넘으면 조용한 곳을 기준으로 여러 덩어리로 나눈다(Moonshine v2는 긴 음성에서 문제가 있었던 이력).
library;

import 'dart:math' as math;
import 'dart:typed_data';

const _frameMs = 20;
const _mergeGapMs = 300; // 이보다 짧은 쉼은 한 덩어리로 본다
const _padMs = 150; // 말소리 앞뒤 여유
const _joinGapMs = 250; // 덩어리 사이에 남길 쉼
const _maxChunkMs = 8000;

class _Seg {
  _Seg(this.start, this.end);
  int start; // 샘플 위치
  int end;
}

/// 끊어 읽기용: 쉼을 기준으로 말소리 구간(대개 단어 하나~몇 개)을 각각 떼어낸다.
/// 짧은 구간은 앞뒤에 무음을 붙여 1초 이상으로 만든다(아주 짧은 소리는 인식이 잘 안 됨).
/// 구간이 너무 많으면(14개 초과) 빈 목록 — 그럴 땐 이어 붙인 결과만 쓴다.
List<Float32List> wordSegments(Float32List s, {int rate = 16000}) {
  final segs = _voiceSegments(s, rate);
  if (segs.isEmpty || segs.length > 14) return const [];
  if (segs.any((g) => g.end - g.start > rate * _maxChunkMs ~/ 1000)) return const [];
  final minLen = rate; // 1초
  return [
    for (final g in segs)
      () {
        final len = g.end - g.start;
        final padEach = len >= minLen ? rate ~/ 10 : (minLen - len) ~/ 2 + rate ~/ 10;
        final out = Float32List(len + padEach * 2);
        out.setRange(padEach, padEach + len, s, g.start);
        return out;
      }(),
  ];
}

/// 말소리 구간(앞뒤 여유 포함). 쉼이 0.3초보다 짧으면 한 구간으로 본다.
List<_Seg> _voiceSegments(Float32List s, int rate) {
  final frame = rate * _frameMs ~/ 1000;
  final nFrames = s.length ~/ frame;
  if (nFrames == 0) return [];

  final rms = List<double>.generate(nFrames, (f) {
    var sum = 0.0;
    for (var i = f * frame; i < (f + 1) * frame; i++) {
      sum += s[i] * s[i];
    }
    return math.sqrt(sum / frame);
  });
  final sorted = [...rms]..sort();
  final noise = sorted[(sorted.length * 0.2).floor()];
  final peak = sorted.last;
  final thr = math.max(0.008, math.min(noise * 2.5 + 0.004, peak * 0.3));

  // 말소리 프레임 → 구간
  final segs = <_Seg>[];
  for (var f = 0; f < nFrames; f++) {
    if (rms[f] <= thr) continue;
    final st = f * frame, en = (f + 1) * frame;
    if (segs.isNotEmpty && st - segs.last.end <= rate * _mergeGapMs ~/ 1000) {
      segs.last.end = en;
    } else {
      segs.add(_Seg(st, en));
    }
  }
  if (segs.isEmpty) return segs;

  final pad = rate * _padMs ~/ 1000;
  for (final g in segs) {
    g.start = math.max(0, g.start - pad);
    g.end = math.min(s.length, g.end + pad);
  }
  return segs;
}

/// 음성이 들어 있는 부분만 남겨 받아쓰기용 덩어리로 나눈다. 말소리가 없으면 빈 목록.
List<Float32List> prepareForAsr(Float32List s, {int rate = 16000}) {
  final segs = _voiceSegments(s, rate);
  if (segs.isEmpty) return const [];

  // 너무 긴 구간은 강제로 자른다.
  final maxLen = rate * _maxChunkMs ~/ 1000;
  final pieces = <_Seg>[];
  for (final g in segs) {
    for (var st = g.start; st < g.end; st += maxLen) {
      pieces.add(_Seg(st, math.min(g.end, st + maxLen)));
    }
  }

  // 구간들을 짧은 쉼으로 이어 붙이되, 한 덩어리가 8초를 넘지 않게 나눈다.
  final gap = rate * _joinGapMs ~/ 1000;
  final chunks = <Float32List>[];
  var cur = <_Seg>[];
  var curLen = 0;
  void flush() {
    if (cur.isEmpty) return;
    final out = Float32List(curLen);
    var o = 0;
    for (var k = 0; k < cur.length; k++) {
      if (k > 0) o += gap; // 0으로 채운 쉼
      out.setRange(o, o + cur[k].end - cur[k].start, s, cur[k].start);
      o += cur[k].end - cur[k].start;
    }
    chunks.add(out);
    cur = [];
    curLen = 0;
  }

  for (final p in pieces) {
    final len = p.end - p.start;
    final add = cur.isEmpty ? len : len + gap;
    if (curLen + add > maxLen) flush();
    curLen += cur.isEmpty ? len : len + gap;
    cur.add(p);
  }
  flush();
  return chunks;
}

/// 끊어 읽은 단어들을 쉼 거의 없이 바짝 붙인다(이어 말한 것처럼 들리게). 8초를 넘으면 null.
Float32List? tightJoin(Float32List s, {int rate = 16000}) {
  final segs = _voiceSegments(s, rate);
  if (segs.length < 2) return null;
  final pad = rate * _padMs ~/ 1000;
  final keep = rate * 30 ~/ 1000; // 말소리 앞뒤로 0.03초만 남김
  final gap = rate * 40 ~/ 1000;
  final pieces = [
    for (final g in segs)
      Float32List.sublistView(s, math.min(g.end, g.start + pad - keep), math.max(g.start + pad - keep, g.end - pad + keep)),
  ];
  final total = pieces.fold<int>(0, (a, p) => a + p.length) + gap * (pieces.length - 1);
  if (total > rate * _maxChunkMs ~/ 1000) return null;
  final out = Float32List(total);
  var o = 0;
  for (var k = 0; k < pieces.length; k++) {
    if (k > 0) o += gap;
    out.setRange(o, o + pieces[k].length, pieces[k]);
    o += pieces[k].length;
  }
  return out;
}

/// 단어를 하나씩 끊어 읽었는지: 말소리 구간이 3개 이상이고, 구간 사이 쉼이 대부분 0.6초 이상.
/// (실험: Moonshine은 아주 천천히 이어 말하면 정확하지만, 단어마다 끊으면 "to"→"tear"처럼 잘못 알아듣는다.)
bool looksWordByWord(Float32List s, {int rate = 16000}) {
  final segs = _voiceSegments(s, rate);
  if (segs.length < 3) return false;
  final pad = rate * _padMs ~/ 1000;
  var longGaps = 0;
  for (var k = 1; k < segs.length; k++) {
    final gap = (segs[k].start + pad) - (segs[k - 1].end - pad);
    if (gap >= rate * 0.6) longGaps++;
  }
  return longGaps >= (segs.length - 1) * 0.6;
}
