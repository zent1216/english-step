/// 발음 채점(강제 정렬, GOP 방식). "이 소리가 정답 문장의 각 단어와 얼마나 맞는가"를 직접 잰다.
///
/// 받아쓰기(Moonshine)는 소리를 "흔한 단어"로 바꾸려는 성질이 있어서 latte를 정확히 말해도 "nothing"으로
/// 받아쓰는 일이 있다. 여기서는 정답 문장을 알고 있으니, CTC 음성 모델(NeMo Conformer-CTC small, 영어)의
/// 프레임별 확률에서 정답 글자열을 억지로 맞춰 본 점수(forced)와 아무 말이나 가장 잘 맞는 점수(free)를
/// 단어 구간마다 비교한다. 차이가 작으면 정답대로 발음한 것이다(Goodness of Pronunciation).
///
/// - 정답 글자열을 덮는 토큰 조합은 단어 경계와 상관없이 모두 허용한다("an iced"를 "a nice"처럼 나눠도 됨).
/// - 모델(int8, 약 46MB)은 처음 한 번 GitHub(sherpa-onnx 공식 배포, 압축 76MB)에서 받는다.
/// - 실행은 sherpa_onnx가 넣어 둔 libonnxruntime.so를 ffi로 직접 부른다([OrtCtcSession]).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'ctc_align.dart';
import 'moonshine.dart' show ModelState;
import 'ort.dart';

export 'ctc_align.dart';

class PronScorer extends ChangeNotifier {
  PronScorer._();
  static final PronScorer instance = PronScorer._();

  static const modelName = 'sherpa-onnx-nemo-ctc-en-conformer-small';
  static const _url =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2';
  static const approxMb = 76;

  ModelState state = ModelState.checking;
  double progress = 0;
  String? error;

  String? _baseDir;
  OrtCtcSession? _session;
  CtcVocab? _vocab;

  bool get isReady => state == ModelState.ready;
  bool get isBusy => state == ModelState.downloading || state == ModelState.extracting;

  String get _modelDir => '$_baseDir/$modelName';
  String get _model => '$_modelDir/model.int8.onnx';
  String get _tokens => '$_modelDir/tokens.txt';

  Future<void> init() async {
    if (_baseDir != null) return;
    _baseDir = '${(await getApplicationSupportDirectory()).path}/pron';
    final ok = File(_model).existsSync() && File(_tokens).existsSync();
    _set(ok ? ModelState.ready : ModelState.missing);
  }

  void _set(ModelState s, {String? err}) {
    state = s;
    error = err;
    notifyListeners();
  }

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
      await Isolate.run(() => extractFileToDisk(archivePath, outPath));
      await archive.delete();
      // 필요 없는 큰 파일(fp32 모델, 예제 음성)은 지운다.
      for (final name in ['model.onnx', 'test_wavs']) {
        final e = FileSystemEntity.typeSync('$_modelDir/$name');
        if (e == FileSystemEntityType.file) File('$_modelDir/$name').deleteSync();
        if (e == FileSystemEntityType.directory) {
          Directory('$_modelDir/$name').deleteSync(recursive: true);
        }
      }
      if (!File(_model).existsSync() || !File(_tokens).existsSync()) throw '모델 파일이 없어요';
      _set(ModelState.ready);
    } catch (e) {
      if (archive.existsSync()) await archive.delete();
      _set(ModelState.error, err: '발음 채점 모델을 받지 못했어요($e).');
    } finally {
      client.close();
    }
  }

  Future<void> deleteModel() async {
    await init();
    _session?.close();
    _session = null;
    _vocab = null;
    final d = Directory(_modelDir);
    if (d.existsSync()) await d.delete(recursive: true);
    _set(ModelState.missing);
  }

  /// 녹음(16kHz)과 정답 문장으로 단어별 발음 점수. 모델이 없거나 실패하면 null.
  WordGops? score(Float32List samples, String target) {
    if (!isReady) return null;
    try {
      _session ??= OrtCtcSession.open(_model);
      _vocab ??= CtcVocab.fromLines(File(_tokens).readAsLinesSync());
      final lp = ctcLogProbs(_session!, samples);
      return wordGops(lp, _vocab!, target);
    } catch (e) {
      debugPrint('발음 채점 실패: $e');
      return null;
    }
  }
}

