/// 칼디(Kaldi) 방식 80차원 로그 멜 필터뱅크. NeMo CTC 발음 채점 모델의 입력.
///
/// kaldi-native-fbank 기본값과 같게 맞췄다(파이썬으로 비교해 오차 0.0001 이하 확인):
/// 25ms 창 / 10ms 간격, snip_edges=false(양 끝 반사), 직류 제거, 프리엠퍼시스 0.97, povey 창,
/// FFT 512, 멜 80개(20Hz~8kHz), 디더 없음, 샘플은 16비트 크기(×32768).
library;

import 'dart:math' as math;
import 'dart:typed_data';

const _rate = 16000;
const _shift = 160;
const _length = 400;
const _nfft = 512;
const melBins = 80;

final Float64List _window = Float64List.fromList([
  for (var i = 0; i < _length; i++)
    math.pow(0.5 - 0.5 * math.cos(2 * math.pi * i / (_length - 1)), 0.85).toDouble(),
]);

class _Bank {
  _Bank(this.start, this.weights);
  final int start;
  final Float64List weights;
}

final List<_Bank> _banks = () {
  double mel(double f) => 1127.0 * math.log(1 + f / 700.0);
  const low = 20.0, high = _rate / 2;
  final ml = mel(low), mh = mel(high);
  final delta = (mh - ml) / (melBins + 1);
  const binWidth = _rate / _nfft;
  return [
    for (var b = 0; b < melBins; b++)
      () {
        final l = ml + b * delta, c = ml + (b + 1) * delta, r = ml + (b + 2) * delta;
        var first = -1;
        final w = <double>[];
        for (var i = 0; i < _nfft ~/ 2; i++) {
          final m = mel(binWidth * i);
          if (m > l && m < r) {
            if (first < 0) first = i;
            w.add(m <= c ? (m - l) / (c - l) : (r - m) / (r - c));
          } else if (first >= 0) {
            break;
          }
        }
        return _Bank(first < 0 ? 0 : first, Float64List.fromList(w));
      }(),
  ];
}();

// 512점 FFT용 비트 반전 표와 회전 인자
final Int32List _rev = () {
  final r = Int32List(_nfft);
  const bits = 9;
  for (var i = 0; i < _nfft; i++) {
    var x = i, y = 0;
    for (var b = 0; b < bits; b++) {
      y = (y << 1) | (x & 1);
      x >>= 1;
    }
    r[i] = y;
  }
  return r;
}();
final Float64List _cos = Float64List.fromList([
  for (var i = 0; i < _nfft ~/ 2; i++) math.cos(-2 * math.pi * i / _nfft),
]);
final Float64List _sin = Float64List.fromList([
  for (var i = 0; i < _nfft ~/ 2; i++) math.sin(-2 * math.pi * i / _nfft),
]);

void _fft(Float64List re, Float64List im) {
  for (var i = 0; i < _nfft; i++) {
    final j = _rev[i];
    if (j > i) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var size = 2; size <= _nfft; size <<= 1) {
    final half = size >> 1, step = _nfft ~/ size;
    for (var i = 0; i < _nfft; i += size) {
      for (var k = 0; k < half; k++) {
        final wr = _cos[k * step], wi = _sin[k * step];
        final a = i + k, b = a + half;
        final xr = re[b] * wr - im[b] * wi;
        final xi = re[b] * wi + im[b] * wr;
        re[b] = re[a] - xr;
        im[b] = im[a] - xi;
        re[a] += xr;
        im[a] += xi;
      }
    }
  }
}

/// 16kHz 음성(-1~1) → 프레임 수 × 80 (프레임 순서로 한 줄씩).
Float32List fbank(Float32List samples, {int rate = 16000}) {
  assert(rate == _rate);
  final n = (samples.length + _shift ~/ 2) ~/ _shift;
  final out = Float32List(n * melBins);
  final frame = Float64List(_length);
  final re = Float64List(_nfft), im = Float64List(_nfft);
  const eps = 1.1920928955078125e-07; // float32 eps
  final len = samples.length;
  for (var f = 0; f < n; f++) {
    final start = f * _shift + _shift ~/ 2 - _length ~/ 2;
    var mean = 0.0;
    for (var i = 0; i < _length; i++) {
      var idx = start + i;
      if (idx < 0) idx = -idx - 1;
      if (idx >= len) idx = 2 * len - idx - 1;
      final v = samples[idx.clamp(0, len - 1)] * 32768.0;
      frame[i] = v;
      mean += v;
    }
    mean /= _length;
    for (var i = 0; i < _length; i++) {
      frame[i] -= mean;
    }
    for (var i = _length - 1; i > 0; i--) {
      frame[i] -= 0.97 * frame[i - 1];
    }
    frame[0] -= 0.97 * frame[0];
    for (var i = 0; i < _nfft; i++) {
      re[i] = i < _length ? frame[i] * _window[i] : 0.0;
      im[i] = 0.0;
    }
    _fft(re, im);
    for (var b = 0; b < melBins; b++) {
      final bank = _banks[b];
      var e = 0.0;
      for (var k = 0; k < bank.weights.length; k++) {
        final i = bank.start + k;
        e += bank.weights[k] * (re[i] * re[i] + im[i] * im[i]);
      }
      out[f * melBins + b] = math.log(e < eps ? eps : e);
    }
  }
  return out;
}

/// 멜 차원별로 평균 0, 표준편차 1로 맞추고 [80 × 프레임] 순서로 바꾼다(NeMo per_feature 정규화).
Float32List normalizeTransposed(Float32List feats, int frames) {
  final out = Float32List(feats.length);
  for (var b = 0; b < melBins; b++) {
    var sum = 0.0;
    for (var t = 0; t < frames; t++) {
      sum += feats[t * melBins + b];
    }
    final mean = sum / frames;
    var sq = 0.0;
    for (var t = 0; t < frames; t++) {
      final d = feats[t * melBins + b] - mean;
      sq += d * d;
    }
    final std = math.sqrt(sq / frames) + 1e-5;
    for (var t = 0; t < frames; t++) {
      out[b * frames + t] = (feats[t * melBins + b] - mean) / std;
    }
  }
  return out;
}
