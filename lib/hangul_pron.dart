/// 영어 → 한글 발음 표기("have a nice day" → "해브 어 나이스 데이").
///
/// CMU 발음 사전(카네기멜런대, BSD 라이선스, `assets/cmudict.txt.gz`, 약 12만 단어)으로 발음기호를 찾고,
/// 발음기호를 한글로 옮긴다. 사전에 없는 단어(이름 등)는 철자 규칙으로 대충 읽는다.
/// 외래어 표기법이 아니라 "소리 나는 대로"에 가깝게 적는다(meet → 미트, please → 플리즈).
library;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HangulPron extends ChangeNotifier {
  HangulPron._();
  static final HangulPron instance = HangulPron._();

  Map<String, List<String>>? _dict;
  Future<void>? _loading;
  final _cache = <String, String>{};

  bool get isReady => _dict != null;

  /// 사전을 읽는다(앱 시작 때 한 번, 기다리지 않아도 됨). 다 읽으면 화면이 다시 그려진다.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final gz = await rootBundle.load('assets/cmudict.txt.gz');
      _dict = await compute(_parse, gz.buffer.asUint8List());
      _cache.clear();
      notifyListeners();
    } catch (_) {
      _loading = null; // 다음에 다시 시도
    }
  }

  /// 테스트용: 사전을 직접 넣는다.
  @visibleForTesting
  void setDictionary(Map<String, List<String>> d) {
    _dict = d;
    _cache.clear();
  }

  /// 문장 전체를 한글로. 사전을 아직 못 읽었으면 빈 문자열.
  String sentence(String text) {
    if (_dict == null) return '';
    final words = text
        .replaceAll('’', "'")
        .split(RegExp(r"[^A-Za-z0-9']+"))
        .where((w) => w.replaceAll("'", '').isNotEmpty);
    final list = words.toList();
    final out = <String>[];
    for (var i = 0; i < list.length; i++) {
      final key = list[i].toLowerCase();
      // 문장 속 기능어는 약하게 소리 난다(an → 언, a → 어, the → 더). 단어 하나만 있으면 원래 소리.
      var weak = list.length > 1 ? _weakForms[key] : null;
      if (key == 'the' && list.length > 1 && i + 1 < list.length && _startsWithVowel(list[i + 1])) {
        weak = '디'; // 모음 앞 the
      }
      final h = weak ?? word(list[i]);
      if (h.isNotEmpty) out.add(h);
    }
    return out.join(' ');
  }

  bool _startsWithVowel(String w) {
    final ph = _dict?[w.toLowerCase()];
    if (ph != null && ph.isNotEmpty) return _isVowel(ph.first.replaceAll(RegExp(r'\d'), ''));
    return RegExp('^[aeiouAEIOU]').hasMatch(w);
  }

  /// 단어 하나를 한글로.
  String word(String w) {
    final key = w.toLowerCase().replaceAll(RegExp(r"^'+|'+$"), '');
    if (key.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(key)) return key;
    return _cache[key] ??= () {
      final o = _overrides[key];
      if (o != null) return o;
      final phones = _dict?[key] ?? spellToPhones(key);
      return phonesToHangul(phones);
    }();
  }
}

Map<String, List<String>> _parse(Uint8List gz) {
  final text = String.fromCharCodes(const GZipDecoder().decodeBytes(gz));
  final map = <String, List<String>>{};
  for (final line in text.split('\n')) {
    final sp = line.indexOf(' ');
    if (sp <= 0) continue;
    map[line.substring(0, sp)] = line.substring(sp + 1).split(' ');
  }
  return map;
}

// 규칙으로 어색하게 나오는 아주 흔한 단어는 직접 적는다.
const _overrides = <String, String>{
  'good': '굿',
  'and': '앤드',
  'of': '어브',
  'okay': '오케이',
  'ok': '오케이',
  // 사전에는 "라테이"처럼 나오지만 실제로는 끝 모음을 짧게 말하는 외래어
  'latte': '라테',
  'lattes': '라테스',
  'cafe': '카페',
  'café': '카페',
};

// 문장 속에서 약하게 소리 나는 기능어(약형). 강하게 말할 때는 사전 소리(an → 앤).
const _weakForms = <String, String>{'a': '어', 'an': '언', 'the': '더', 'of': '어브', 'to': '투'};

// ---- 발음기호(ARPAbet) → 한글 ----

const _cho = [
  'ㄱ',
  'ㄲ',
  'ㄴ',
  'ㄷ',
  'ㄸ',
  'ㄹ',
  'ㅁ',
  'ㅂ',
  'ㅃ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅉ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];
const _jung = [
  'ㅏ',
  'ㅐ',
  'ㅑ',
  'ㅒ',
  'ㅓ',
  'ㅔ',
  'ㅕ',
  'ㅖ',
  'ㅗ',
  'ㅘ',
  'ㅙ',
  'ㅚ',
  'ㅛ',
  'ㅜ',
  'ㅝ',
  'ㅞ',
  'ㅟ',
  'ㅠ',
  'ㅡ',
  'ㅢ',
  'ㅣ',
];
const _jong = [
  '',
  'ㄱ',
  'ㄲ',
  'ㄳ',
  'ㄴ',
  'ㄵ',
  'ㄶ',
  'ㄷ',
  'ㄹ',
  'ㄺ',
  'ㄻ',
  'ㄼ',
  'ㄽ',
  'ㄾ',
  'ㄿ',
  'ㅀ',
  'ㅁ',
  'ㅂ',
  'ㅄ',
  'ㅅ',
  'ㅆ',
  'ㅇ',
  'ㅈ',
  'ㅊ',
  'ㅋ',
  'ㅌ',
  'ㅍ',
  'ㅎ',
];

class _Syl {
  _Syl(this.cho, this.jung);
  String cho;
  String jung;
  String jong = '';
  String get text => String.fromCharCode(
    0xAC00 + (_cho.indexOf(cho) * 21 + _jung.indexOf(jung)) * 28 + _jong.indexOf(jong),
  );
}

// 모음 → 한글 모음들(이중모음은 두 글자: AY → 아이)
const _vowels = <String, List<String>>{
  'AA': ['ㅏ'],
  'AE': ['ㅐ'],
  'AH': ['ㅓ'],
  'AO': ['ㅗ'],
  'AW': ['ㅏ', 'ㅜ'],
  'AY': ['ㅏ', 'ㅣ'],
  'EH': ['ㅔ'],
  'ER': ['ㅓ'],
  'EY': ['ㅔ', 'ㅣ'],
  'IH': ['ㅣ'],
  'IY': ['ㅣ'],
  'OW': ['ㅗ', 'ㅜ'],
  'OY': ['ㅗ', 'ㅣ'],
  'UH': ['ㅜ'],
  'UW': ['ㅜ'],
};
const _shortVowels = {'AE', 'EH', 'IH', 'UH', 'AH', 'AA', 'AO'};

// 모음 앞 자음(초성)
const _onset = <String, String>{
  'B': 'ㅂ',
  'CH': 'ㅊ',
  'D': 'ㄷ',
  'DH': 'ㄷ',
  'F': 'ㅍ',
  'G': 'ㄱ',
  'HH': 'ㅎ',
  'JH': 'ㅈ',
  'K': 'ㅋ',
  'L': 'ㄹ',
  'M': 'ㅁ',
  'N': 'ㄴ',
  'NG': 'ㅇ',
  'P': 'ㅍ',
  'R': 'ㄹ',
  'S': 'ㅅ',
  'SH': 'ㅅ',
  'T': 'ㅌ',
  'TH': 'ㅆ',
  'V': 'ㅂ',
  'Z': 'ㅈ',
  'ZH': 'ㅈ',
};

// 혼자 남은 자음(뒤에 모음이 없을 때): 받침 또는 "ㅡ"를 붙인 한 글자
const _alone = <String, (String, String)>{
  'B': ('ㅂ', 'ㅡ'),
  'D': ('ㄷ', 'ㅡ'),
  'G': ('ㄱ', 'ㅡ'),
  'F': ('ㅍ', 'ㅡ'),
  'V': ('ㅂ', 'ㅡ'),
  'S': ('ㅅ', 'ㅡ'),
  'Z': ('ㅈ', 'ㅡ'),
  'TH': ('ㅅ', 'ㅡ'),
  'DH': ('ㄷ', 'ㅡ'),
  'CH': ('ㅊ', 'ㅣ'),
  'JH': ('ㅈ', 'ㅣ'),
  'SH': ('ㅅ', 'ㅣ'),
  'ZH': ('ㅈ', 'ㅣ'),
  'K': ('ㅋ', 'ㅡ'),
  'P': ('ㅍ', 'ㅡ'),
  'T': ('ㅌ', 'ㅡ'),
  'M': ('ㅁ', 'ㅡ'),
  'N': ('ㄴ', 'ㅡ'),
  'L': ('ㄹ', 'ㅡ'),
  'NG': ('ㅇ', 'ㅡ'),
};

// w·y가 앞에 붙은 모음
const _wGlide = {'ㅏ': 'ㅘ', 'ㅓ': 'ㅝ', 'ㅗ': 'ㅝ', 'ㅐ': 'ㅙ', 'ㅔ': 'ㅞ', 'ㅣ': 'ㅟ', 'ㅜ': 'ㅜ'};
const _yGlide = {'ㅏ': 'ㅑ', 'ㅓ': 'ㅕ', 'ㅗ': 'ㅛ', 'ㅐ': 'ㅒ', 'ㅔ': 'ㅖ', 'ㅣ': 'ㅣ', 'ㅜ': 'ㅠ'};
// sh 뒤 모음(she → 쉬, shop → 샵)
const _shGlide = {'ㅏ': 'ㅑ', 'ㅓ': 'ㅕ', 'ㅗ': 'ㅛ', 'ㅐ': 'ㅒ', 'ㅔ': 'ㅖ', 'ㅣ': 'ㅟ', 'ㅜ': 'ㅠ'};

bool _isVowel(String p) => _vowels.containsKey(p);

/// 발음기호 목록(강세 숫자 있어도 됨) → 한글.
String phonesToHangul(List<String> raw) {
  final ph = [for (final p in raw) p.replaceAll(RegExp(r'\d'), '')];
  final stress0 = [for (final p in raw) p.endsWith('0')];
  final out = <_Syl>[];
  String? pendingOnset; // 다음 모음에 붙을 초성
  String? glide; // 'W' / 'Y' / 'SH'
  for (var i = 0; i < ph.length; i++) {
    final p = ph[i];
    final next = i + 1 < ph.length ? ph[i + 1] : null;
    if (_isVowel(p)) {
      var js = List<String>.of(_vowels[p]!);
      // 낱말 끝이 아닌 OW는 "오"(home → 홈), 끝이면 "오우"(go → 고우)
      if (p == 'OW' && next != null) js = ['ㅗ'];
      // 끝의 "-tle/-ple"(AH0 L)은 "으"(little → 리틀)
      if (p == 'AH' && stress0[i] && next == 'L' && i + 2 == ph.length) js = ['ㅡ'];
      var first = js.first;
      if (glide == 'W') first = _wGlide[first] ?? first;
      if (glide == 'Y') first = _yGlide[first] ?? first;
      if (glide == 'SH') first = _shGlide[first] ?? first;
      final cho = pendingOnset ?? 'ㅇ';
      // L이 초성이면 앞 글자에 ㄹ 받침을 더한다(please → 플리즈, hello → 헐로우)
      if (cho == 'ㄹ' &&
          glide == null &&
          i > 0 &&
          ph[i - 1] == 'L' &&
          out.isNotEmpty &&
          out.last.jong.isEmpty) {
        out.last.jong = 'ㄹ';
      }
      out.add(_Syl(cho, first));
      for (final j in js.skip(1)) {
        out.add(_Syl('ㅇ', j));
      }
      pendingOnset = null;
      glide = null;
      continue;
    }
    // 자음
    final nextIsVowel = next != null && _isVowel(next);
    final nextIsGlideVowel =
        (next == 'W' || next == 'Y') && i + 2 < ph.length && _isVowel(ph[i + 2]);
    if (p == 'W' || p == 'Y') {
      if (nextIsVowel) {
        glide = p;
      } else if (p == 'W') {
        out.add(_Syl('ㅇ', 'ㅜ'));
      }
      continue;
    }
    if (nextIsVowel || (nextIsGlideVowel && p != 'NG')) {
      if (p == 'NG') {
        // 모음 앞 ng(singer): 받침 ㅇ + 다음 글자는 ㅇ으로 시작
        if (out.isNotEmpty && out.last.jong.isEmpty) out.last.jong = 'ㅇ';
        continue;
      }
      pendingOnset = _onset[p];
      if (p == 'SH') glide = 'SH';
      continue;
    }
    // 뒤에 모음이 없는 자음: 받침이 되거나 "ㅡ"를 붙여 한 글자
    final prev = i > 0 ? ph[i - 1] : null;
    final last = out.isEmpty ? null : out.last;
    final canJong = last != null && last.jong.isEmpty && prev != null && _isVowel(prev);
    if (p == 'HH') continue; // 받침 h는 소리 내지 않음
    if (p == 'R') {
      // 모음 뒤 r: "아"(car → 카)는 그대로, 에/이/우/오 뒤는 "어"를 붙인다(where → 웨어, here → 히어)
      // "오" 뒤는 붙이지 않는다(for → 포, more → 모). 단 or 하나만 있으면 "오어".
      final onlyOr = prev == 'AO' && out.length == 1 && out.first.cho == 'ㅇ';
      if (onlyOr || (prev != null && const {'EH', 'IH', 'IY', 'UH', 'UW'}.contains(prev))) {
        out.add(_Syl('ㅇ', 'ㅓ'));
      }
      continue;
    }
    // ts → 츠(boats → 보츠, it's → 잇츠), dz → 즈(friends → 프렌즈)
    if ((p == 'T' && next == 'S') || (p == 'D' && next == 'Z')) {
      final after = i + 2 < ph.length ? ph[i + 2] : null;
      if (after == null || !_isVowel(after)) {
        if (p == 'T' && canJong && _shortVowels.contains(prev)) last.jong = 'ㅅ';
        out.add(_Syl(p == 'T' ? 'ㅊ' : 'ㅈ', 'ㅡ'));
        i++;
        continue;
      }
    }
    if (canJong && (p == 'M' || p == 'N' || p == 'NG' || p == 'L')) {
      last.jong = {'M': 'ㅁ', 'N': 'ㄴ', 'NG': 'ㅇ', 'L': 'ㄹ'}[p]!;
      continue;
    }
    // 짧은 모음 뒤 p/t/k/g는 받침(cat → 캣, stop → 스탑, bag → 백)
    if (canJong && _shortVowels.contains(prev) && const {'P', 'T', 'K', 'G'}.contains(p)) {
      last.jong = {'P': 'ㅂ', 'T': 'ㅅ', 'K': 'ㄱ', 'G': 'ㄱ'}[p]!;
      continue;
    }
    // 받침 없는 "ㅡ" 글자 뒤에 오는 m/n은 그 글자의 받침(rhythm → 리듬)
    if ((p == 'M' || p == 'N') && last != null && last.jong.isEmpty && last.jung == 'ㅡ') {
      last.jong = p == 'M' ? 'ㅁ' : 'ㄴ';
      continue;
    }
    final a = _alone[p];
    if (a == null) continue;
    if (p == 'NG') {
      if (last != null && last.jong.isEmpty) {
        last.jong = 'ㅇ';
        continue;
      }
    }
    out.add(_Syl(a.$1 == 'ㅇ' ? 'ㅇ' : a.$1, a.$2));
  }
  return out.map((s) => s.text).join();
}

/// 사전에 없는 단어를 철자로 대충 발음기호로 바꾼다.
List<String> spellToPhones(String w) {
  var s = w.toLowerCase().replaceAll(RegExp("[^a-z]"), '');
  if (s.length > 2 && s.endsWith('e') && !s.endsWith('ee')) s = s.substring(0, s.length - 1);
  const multi = <String, List<String>>{
    'tch': ['CH'],
    'sh': ['SH'],
    'ch': ['CH'],
    'th': ['TH'],
    'ph': ['F'],
    'ck': ['K'],
    'ng': ['NG'],
    'qu': ['K', 'W'],
    'wh': ['W'],
    'ee': ['IY'],
    'ea': ['IY'],
    'oo': ['UW'],
    'ai': ['EY'],
    'ay': ['EY'],
    'oa': ['OW'],
    'ou': ['AW'],
    'ow': ['OW'],
    'oi': ['OY'],
    'oy': ['OY'],
    'au': ['AO'],
    'aw': ['AO'],
    'er': ['ER'],
    'ir': ['ER'],
    'ur': ['ER'],
    'ar': ['AA', 'R'],
    'or': ['AO', 'R'],
  };
  const single = <String, String>{
    'a': 'AE',
    'e': 'EH',
    'i': 'IH',
    'o': 'AA',
    'u': 'AH',
    'b': 'B',
    'd': 'D',
    'f': 'F',
    'g': 'G',
    'h': 'HH',
    'j': 'JH',
    'k': 'K',
    'l': 'L',
    'm': 'M',
    'n': 'N',
    'p': 'P',
    'r': 'R',
    's': 'S',
    't': 'T',
    'v': 'V',
    'w': 'W',
    'z': 'Z',
  };
  final out = <String>[];
  var i = 0;
  while (i < s.length) {
    var matched = false;
    for (final len in [3, 2]) {
      if (i + len <= s.length && multi.containsKey(s.substring(i, i + len))) {
        out.addAll(multi[s.substring(i, i + len)]!);
        i += len;
        matched = true;
        break;
      }
    }
    if (matched) continue;
    final c = s[i];
    final nx = i + 1 < s.length ? s[i + 1] : '';
    if (c == 'c') {
      out.add('eiy'.contains(nx) && nx.isNotEmpty ? 'S' : 'K');
    } else if (c == 'x') {
      out.addAll(['K', 'S']);
    } else if (c == 'y') {
      out.add(i == 0 ? 'Y' : 'IY');
    } else if (c == 'q') {
      out.add('K');
    } else if (single.containsKey(c)) {
      // 같은 자음 두 개는 하나로
      if (out.isNotEmpty && out.last == single[c] && !_isVowel(single[c]!)) {
        i++;
        continue;
      }
      out.add(single[c]!);
    }
    i++;
  }
  return out;
}
