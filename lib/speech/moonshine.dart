/// Moonshine v2(base, 영어) 음성 인식 엔진. sherpa-onnx로 폰 안에서 돌린다(오프라인, 무료).
///
/// 모델(약 111MB)은 앱에 넣지 않고 처음 한 번 GitHub(sherpa-onnx 공식 배포)에서 받아
/// 앱 전용 폴더에 풀어둔다. 받기 전에는 폰 기본 음성 인식으로 대신한다.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

enum ModelState { checking, missing, downloading, extracting, ready, error }

class MoonshineEngine extends ChangeNotifier {
  MoonshineEngine._();
  static final MoonshineEngine instance = MoonshineEngine._();

  static const modelName = 'sherpa-onnx-moonshine-base-en-quantized-2026-02-27';
  static const _url =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2';
  static const approxMb = 111;
  static const sampleRate = 16000;

  ModelState state = ModelState.checking;
  double progress = 0; // 받기 진행률 0~1
  String? error;

  String? _baseDir;
  so.OfflineRecognizer? _recognizer;
  static bool _bindings = false;

  bool get isReady => state == ModelState.ready;
  bool get isBusy => state == ModelState.downloading || state == ModelState.extracting;

  String get _modelDir => '$_baseDir/$modelName';
  String get _encoder => '$_modelDir/encoder_model.ort';
  String get _decoder => '$_modelDir/decoder_model_merged.ort';
  String get _tokens => '$_modelDir/tokens.txt';

  /// 앱 시작 때 한 번: 모델이 이미 받아져 있는지 확인.
  Future<void> init() async {
    if (_baseDir != null) return;
    _baseDir = '${(await getApplicationSupportDirectory()).path}/asr';
    final ok = [_encoder, _decoder, _tokens].every((p) => File(p).existsSync());
    _set(ok ? ModelState.ready : ModelState.missing);
  }

  void _set(ModelState s, {String? err}) {
    state = s;
    error = err;
    notifyListeners();
  }

  /// 모델 받기 → 압축 풀기. 진행 상황은 [state]/[progress]로 알린다.
  Future<void> download() async {
    if (isBusy || isReady) return;
    await init();
    final base = Directory(_baseDir!);
    await base.create(recursive: true);
    final archive = File('${base.path}/$modelName.tar.bz2');
    progress = 0;
    _set(ModelState.downloading);
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(_url)));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final total = res.contentLength ?? approxMb * 1000 * 1000;
      var got = 0;
      final sink = archive.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        final p = (got / total).clamp(0.0, 1.0);
        if (p - progress >= 0.01 || p == 1) {
          progress = p;
          notifyListeners();
        }
      }
      await sink.close();

      _set(ModelState.extracting);
      final archivePath = archive.path, outPath = base.path;
      // 압축 풀기는 오래 걸려서(수십 초) 별도 isolate에서 한다.
      await Isolate.run(() => extractFileToDisk(archivePath, outPath));
      await archive.delete();
      final wavs = Directory('$_modelDir/test_wavs');
      if (wavs.existsSync()) await wavs.delete(recursive: true);
      if (![_encoder, _decoder, _tokens].every((p) => File(p).existsSync())) {
        throw '모델 파일이 없어요';
      }
      _set(ModelState.ready);
    } catch (e) {
      if (archive.existsSync()) await archive.delete();
      _set(ModelState.error, err: '모델을 받지 못했어요($e). 인터넷 연결을 확인하고 다시 시도해주세요.');
    } finally {
      client.close();
    }
  }

  so.OfflineRecognizer _load() {
    if (!_bindings) {
      so.initBindings();
      _bindings = true;
    }
    return _recognizer ??= so.OfflineRecognizer(so.OfflineRecognizerConfig(
      model: so.OfflineModelConfig(
        moonshine: so.OfflineMoonshineModelConfig(encoder: _encoder, mergedDecoder: _decoder),
        tokens: _tokens,
        numThreads: 2,
        debug: false,
      ),
    ));
  }

  /// 16kHz 모노 음성을 영어 문장으로. 짧은 문장은 폰에서 1초 안팎.
  String transcribe(Float32List samples) {
    final rec = _load();
    final stream = rec.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      rec.decode(stream);
      return rec.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  /// 내 목소리 다시 듣기용 WAV 저장.
  String? saveWave(Float32List samples) {
    if (_baseDir == null) return null;
    _load();
    final path = '$_baseDir/last_take.wav';
    return so.writeWave(filename: path, samples: samples, sampleRate: sampleRate) ? path : null;
  }

  /// 모델 지우기(용량 확보).
  Future<void> deleteModel() async {
    _recognizer?.free();
    _recognizer = null;
    final dir = Directory(_modelDir);
    if (dir.existsSync()) await dir.delete(recursive: true);
    _set(ModelState.missing);
  }
}
