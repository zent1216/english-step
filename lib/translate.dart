/// 구글 ML Kit 기기 내 번역(영어 → 한국어). 무료이고, 모델을 한 번 받은 뒤에는 오프라인으로 동작한다.
/// 직역 위주라 노래 가사의 비유는 어색할 수 있다.
library;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// 안드로이드/iOS에서만 동작한다(웹·데스크톱 미지원).
bool get canTranslateOnDevice =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final _models = OnDeviceTranslatorModelManager();

/// 영어·한국어 번역 모델이 이미 받아져 있는지.
Future<bool> translationModelsReady() async =>
    await _models.isModelDownloaded(TranslateLanguage.english.bcpCode) &&
    await _models.isModelDownloaded(TranslateLanguage.korean.bcpCode);

/// [texts]를 차례로 번역한다. 모델이 없으면 먼저 받는다(와이파이가 아니어도 받음).
/// [onProgress]는 (끝난 개수, 전체 개수).
Future<List<String>> translateToKorean(
  List<String> texts, {
  void Function(int done, int total)? onProgress,
}) async {
  for (final lang in [TranslateLanguage.english, TranslateLanguage.korean]) {
    if (!await _models.isModelDownloaded(lang.bcpCode)) {
      await _models.downloadModel(lang.bcpCode, isWifiRequired: false);
    }
  }
  final translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.korean,
  );
  try {
    final out = <String>[];
    // 후렴처럼 같은 줄이 반복되면 한 번만 번역한다.
    final cache = <String, String>{};
    for (var i = 0; i < texts.length; i++) {
      final t = texts[i].trim();
      out.add(t.isEmpty ? '' : cache[t] ??= await translator.translateText(t));
      onProgress?.call(i + 1, texts.length);
    }
    return out;
  } finally {
    await translator.close();
  }
}
