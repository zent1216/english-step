/// Lv.0 첫걸음 문장. Tatoeba(tatoeba.org, CC BY 2.0 FR)의 영어-한국어 문장 쌍 중
/// 자주 쓰는 단어 1,000개 안에서만 된 3~7단어 문장을 골라 사람이 검수했다.
/// 만드는 법은 CLAUDE.md의 "Lv.0 첫걸음 문장" 참고.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

const sentenceSetSize = 10;
const tatoebaCredit = '문장 출처: Tatoeba (tatoeba.org) · CC BY 2.0 FR';

class PracticeSentence {
  const PracticeSentence(this.en, this.ko, this.src);
  final String en;
  final String ko;
  final String src; // "#영어문장번호 작성자 / #한국어문장번호 작성자"
}

List<PracticeSentence>? _cache;

Future<List<PracticeSentence>> loadLv0Sentences() async {
  return _cache ??= (jsonDecode(await rootBundle.loadString('assets/tatoeba_lv0.json')) as List)
      .map((e) => PracticeSentence(e['en'] as String, e['ko'] as String, e['src'] as String))
      .toList();
}

/// 10개씩 묶은 세트 목록.
List<List<PracticeSentence>> chunkSets(List<PracticeSentence> all) => [
      for (var i = 0; i < all.length; i += sentenceSetSize)
        all.sublist(i, (i + sentenceSetSize).clamp(0, all.length)),
    ];

String setId(int index) => 'lv0-$index';
