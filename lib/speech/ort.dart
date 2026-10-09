/// ONNX Runtime C API를 dart:ffi로 직접 부른다(발음 채점 모델용).
///
/// 새 라이브러리를 넣지 않고, sherpa_onnx가 이미 앱에 넣어 둔 `libonnxruntime.so`를 그대로 쓴다.
/// OrtApi는 함수 포인터 표이고 순서가 바뀌지 않으므로(뒤에만 추가됨) 번호로 함수를 꺼낸다.
/// 번호는 microsoft/onnxruntime `onnxruntime_c_api.h`의 `struct OrtApi` 순서.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// OrtApi 함수 번호
const _getErrorMessage = 2;
const _createEnv = 3;
const _createSession = 7;
const _run = 9;
const _createSessionOptions = 10;
const _setGraphOptLevel = 23;
const _setIntraOpNumThreads = 24;
const _createTensorWithData = 49;
const _getTensorMutableData = 51;
const _getDimensionsCount = 61;
const _getDimensions = 62;
const _getTensorTypeAndShape = 65;
const _createCpuMemoryInfo = 69;
const _releaseEnv = 92;
const _releaseStatus = 93;
const _releaseMemoryInfo = 94;
const _releaseSession = 95;
const _releaseValue = 96;
const _releaseTensorTypeAndShapeInfo = 99;
const _releaseSessionOptions = 100;

const _apiVersion = 17; // ORT 1.17 이상이면 지원(sherpa_onnx 1.13.8은 더 새 버전을 넣어 둠)

typedef _GetApiBaseC = Pointer<IntPtr> Function();
typedef _GetApiC = Pointer<Pointer<Void>> Function(Uint32);
typedef _GetApiD = Pointer<Pointer<Void>> Function(int);

typedef _ReleaseC = Void Function(Pointer<Void>);
typedef _ReleaseD = void Function(Pointer<Void>);
typedef _ErrMsgC = Pointer<Utf8> Function(Pointer<Void>);
typedef _CreateEnvC = Pointer<Void> Function(Int32, Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _CreateEnvD = Pointer<Void> Function(int, Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _CreateOptsC = Pointer<Void> Function(Pointer<Pointer<Void>>);
typedef _SetIntC = Pointer<Void> Function(Pointer<Void>, Int32);
typedef _SetIntD = Pointer<Void> Function(Pointer<Void>, int);
typedef _CreateSessionC =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Void>, Pointer<Pointer<Void>>);
typedef _CreateMemC = Pointer<Void> Function(Int32, Int32, Pointer<Pointer<Void>>);
typedef _CreateMemD = Pointer<Void> Function(int, int, Pointer<Pointer<Void>>);
typedef _CreateTensorC =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      Size,
      Pointer<Int64>,
      Size,
      Int32,
      Pointer<Pointer<Void>>,
    );
typedef _CreateTensorD =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<Int64>,
      int,
      int,
      Pointer<Pointer<Void>>,
    );
typedef _RunC =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Void>>,
      Size,
      Pointer<Pointer<Utf8>>,
      Size,
      Pointer<Pointer<Void>>,
    );
typedef _RunD =
    Pointer<Void> Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Void>>,
      int,
      Pointer<Pointer<Utf8>>,
      int,
      Pointer<Pointer<Void>>,
    );
typedef _GetDataC = Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _GetShapeInfoC = Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _GetDimCountC = Pointer<Void> Function(Pointer<Void>, Pointer<Size>);
typedef _GetDimsC = Pointer<Void> Function(Pointer<Void>, Pointer<Int64>, Size);
typedef _GetDimsD = Pointer<Void> Function(Pointer<Void>, Pointer<Int64>, int);

class OrtException implements Exception {
  OrtException(this.message);
  final String message;
  @override
  String toString() => 'OrtException: $message';
}

/// 2차원 결과 [rows][cols]를 한 줄로 담은 것.
class Matrix {
  Matrix(this.rows, this.cols, this.data);
  final int rows;
  final int cols;
  final Float32List data;
  double at(int r, int c) => data[r * cols + c];
}

/// 모델 하나(입력: float [1, featDim, T] + int64 [1], 출력: float [1, T', V])를 돌리는 세션.
class OrtCtcSession {
  OrtCtcSession._(this._api, this._env, this._session, this._mem);

  final Pointer<Pointer<Void>> _api;
  final Pointer<Void> _env;
  final Pointer<Void> _session;
  final Pointer<Void> _mem;
  bool _closed = false;

  static DynamicLibrary? _lib;

  /// [libraryPath]를 주지 않으면 앱에 들어 있는 libonnxruntime.so를 연다.
  static DynamicLibrary _open(String? libraryPath) {
    if (_lib != null) return _lib!;
    if (libraryPath != null) return _lib = DynamicLibrary.open(libraryPath);
    if (Platform.isAndroid || Platform.isLinux) {
      return _lib = DynamicLibrary.open('libonnxruntime.so');
    }
    if (Platform.isIOS || Platform.isMacOS) return _lib = DynamicLibrary.process();
    return _lib = DynamicLibrary.open('onnxruntime.dll');
  }

  static Pointer<NativeFunction<T>> _fn<T extends Function>(Pointer<Pointer<Void>> api, int i) =>
      api[i].cast<NativeFunction<T>>();

  static void _check(Pointer<Pointer<Void>> api, Pointer<Void> status) {
    if (status == nullptr) return;
    final msg = _fn<_ErrMsgC>(api, _getErrorMessage).asFunction<_ErrMsgC>()(status).toDartString();
    _fn<_ReleaseC>(api, _releaseStatus).asFunction<_ReleaseD>()(status);
    throw OrtException(msg);
  }

  static OrtCtcSession open(String modelPath, {int threads = 2, String? libraryPath}) {
    final lib = _open(libraryPath);
    final base = lib.lookupFunction<_GetApiBaseC, _GetApiBaseC>('OrtGetApiBase')();
    final getApi = Pointer<NativeFunction<_GetApiC>>.fromAddress(base[0]).asFunction<_GetApiD>();
    final api = getApi(_apiVersion);
    if (api == nullptr) throw OrtException('ONNX Runtime 버전이 너무 오래됐어요');

    return using((arena) {
      final out = arena<Pointer<Void>>();
      _check(
        api,
        _fn<_CreateEnvC>(api, _createEnv).asFunction<_CreateEnvD>()(
          3,
          'pron'.toNativeUtf8(allocator: arena),
          out,
        ),
      ); // 3 = ERROR 이상만 기록
      final env = out.value;
      _check(api, _fn<_CreateOptsC>(api, _createSessionOptions).asFunction<_CreateOptsC>()(out));
      final opts = out.value;
      _check(api, _fn<_SetIntC>(api, _setIntraOpNumThreads).asFunction<_SetIntD>()(opts, threads));
      _check(api, _fn<_SetIntC>(api, _setGraphOptLevel).asFunction<_SetIntD>()(opts, 99));
      _check(
        api,
        _fn<_CreateSessionC>(api, _createSession).asFunction<_CreateSessionC>()(
          env,
          modelPath.toNativeUtf8(allocator: arena),
          opts,
          out,
        ),
      );
      final session = out.value;
      _fn<_ReleaseC>(api, _releaseSessionOptions).asFunction<_ReleaseD>()(opts);
      // 0 = OrtDeviceAllocator, 0 = OrtMemTypeDefault
      _check(api, _fn<_CreateMemC>(api, _createCpuMemoryInfo).asFunction<_CreateMemD>()(0, 0, out));
      return OrtCtcSession._(api, env, session, out.value);
    });
  }

  /// [features]: featDim × T (특징 차원이 먼저, 시간 순으로 한 줄씩).
  Matrix run(
    Float32List features,
    int featDim,
    int frames, {
    String featName = 'audio_signal',
    String lenName = 'length',
    String outName = 'logprobs',
  }) {
    if (_closed) throw OrtException('세션이 닫혔어요');
    final api = _api;
    return using((arena) {
      final out = arena<Pointer<Void>>();
      final createTensor = _fn<_CreateTensorC>(
        api,
        _createTensorWithData,
      ).asFunction<_CreateTensorD>();

      final featBuf = arena<Float>(features.length);
      featBuf.asTypedList(features.length).setAll(0, features);
      final featShape = arena<Int64>(3)
        ..[0] = 1
        ..[1] = featDim
        ..[2] = frames;
      _check(api, createTensor(_mem, featBuf.cast(), features.length * 4, featShape, 3, 1, out));
      final featVal = out.value;

      final lenBuf = arena<Int64>(1)..[0] = frames;
      final lenShape = arena<Int64>(1)..[0] = 1;
      _check(api, createTensor(_mem, lenBuf.cast(), 8, lenShape, 1, 7, out)); // 7 = INT64
      final lenVal = out.value;

      final inNames = arena<Pointer<Utf8>>(2)
        ..[0] = featName.toNativeUtf8(allocator: arena)
        ..[1] = lenName.toNativeUtf8(allocator: arena);
      final inVals = arena<Pointer<Void>>(2)
        ..[0] = featVal
        ..[1] = lenVal;
      final outNames = arena<Pointer<Utf8>>(1)..[0] = outName.toNativeUtf8(allocator: arena);
      final outVals = arena<Pointer<Void>>(1)..[0] = nullptr;
      final release = _fn<_ReleaseC>(api, _releaseValue).asFunction<_ReleaseD>();
      try {
        _check(
          api,
          _fn<_RunC>(api, _run).asFunction<_RunD>()(
            _session,
            nullptr,
            inNames,
            inVals,
            2,
            outNames,
            1,
            outVals,
          ),
        );
      } finally {
        release(featVal);
        release(lenVal);
      }
      final result = outVals[0];
      try {
        _check(
          api,
          _fn<_GetShapeInfoC>(api, _getTensorTypeAndShape).asFunction<_GetShapeInfoC>()(
            result,
            out,
          ),
        );
        final info = out.value;
        final cnt = arena<Size>();
        _check(
          api,
          _fn<_GetDimCountC>(api, _getDimensionsCount).asFunction<_GetDimCountC>()(info, cnt),
        );
        final dims = arena<Int64>(cnt.value);
        _check(
          api,
          _fn<_GetDimsC>(api, _getDimensions).asFunction<_GetDimsD>()(info, dims, cnt.value),
        );
        _fn<_ReleaseC>(api, _releaseTensorTypeAndShapeInfo).asFunction<_ReleaseD>()(info);
        final rows = dims[cnt.value - 2], cols = dims[cnt.value - 1];
        _check(
          api,
          _fn<_GetDataC>(api, _getTensorMutableData).asFunction<_GetDataC>()(result, out),
        );
        final data = Float32List.fromList(out.value.cast<Float>().asTypedList(rows * cols));
        return Matrix(rows, cols, data);
      } finally {
        release(result);
      }
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _fn<_ReleaseC>(_api, _releaseSession).asFunction<_ReleaseD>()(_session);
    _fn<_ReleaseC>(_api, _releaseMemoryInfo).asFunction<_ReleaseD>()(_mem);
    _fn<_ReleaseC>(_api, _releaseEnv).asFunction<_ReleaseD>()(_env);
  }
}
