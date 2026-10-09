/// 마이크 녹음(16kHz 모노 PCM). 말이 끝나고 잠깐 조용해지면 자동으로 멈춘다.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

class TakeRecorder {
  final _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final _bytes = BytesBuilder(copy: false);
  Completer<Float32List>? _done;

  /// 0~1 소리 크기(화면 표시용).
  void Function(double level)? onLevel;

  static const _rate = 16000;
  // 천천히·띄엄띄엄 말해도 끊기지 않게 넉넉히 기다린다.
  static const _silenceAfterSpeech = Duration(milliseconds: 2200);
  static const _noSpeechTimeout = Duration(seconds: 8);
  // 긴 녹음은 Moonshine 쪽에서 조용한 곳을 기준으로 잘라 나눠 받아쓴다(moonshine.dart).
  static const _maxLength = Duration(seconds: 20);
  // 처음 0.3초로 주변 소음을 재서 "말하는 중" 기준을 정한다(작은 목소리도 잡히게).
  static const _calibration = Duration(milliseconds: 300);
  static const _minSpeechLevel = 0.012;

  bool _heardSpeech = false;
  DateTime _lastLoud = DateTime.now();
  DateTime _started = DateTime.now();
  double _noiseSum = 0;
  int _noiseCount = 0;
  double _speechLevel = 0.03;

  Future<bool> hasPermission() => _rec.hasPermission();

  /// 녹음을 시작하고, 끝나면(자동 또는 [stop]) 음성 샘플을 돌려준다.
  Future<Float32List> record() async {
    _bytes.clear();
    _heardSpeech = false;
    _noiseSum = 0;
    _noiseCount = 0;
    _speechLevel = 0.03;
    _started = _lastLoud = DateTime.now();
    _done = Completer<Float32List>();
    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _rate,
      numChannels: 1,
      autoGain: true,
      noiseSuppress: true,
    ));
    _sub = stream.listen(_onChunk);
    return _done!.future;
  }

  void _onChunk(Uint8List chunk) {
    _bytes.add(chunk);
    final data = ByteData.sublistView(chunk);
    var sum = 0.0;
    final n = chunk.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    final rms = n == 0 ? 0.0 : math.sqrt(sum / n);
    onLevel?.call((rms * 6).clamp(0.0, 1.0));
    final now = DateTime.now();
    if (now.difference(_started) < _calibration) {
      _noiseSum += rms;
      _noiseCount++;
      _speechLevel = math.max(_minSpeechLevel, (_noiseSum / _noiseCount) * 2.5);
    }
    if (rms > _speechLevel) {
      _heardSpeech = true;
      _lastLoud = now;
    }
    final elapsed = now.difference(_started);
    if ((_heardSpeech && now.difference(_lastLoud) > _silenceAfterSpeech) ||
        (!_heardSpeech && elapsed > _noSpeechTimeout) ||
        elapsed > _maxLength) {
      stop();
    }
  }

  bool get heardSpeech => _heardSpeech;

  Future<void> stop() async {
    final done = _done;
    if (done == null || done.isCompleted) return;
    await _sub?.cancel();
    _sub = null;
    await _rec.stop();
    final bytes = _bytes.takeBytes();
    final data = ByteData.sublistView(bytes);
    final out = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    done.complete(out);
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    if (await _rec.isRecording()) await _rec.stop();
    final done = _done;
    if (done != null && !done.isCompleted) done.complete(Float32List(0));
  }

  void dispose() {
    _rec.dispose();
  }
}
