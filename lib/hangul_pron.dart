/// 영어 → 한글 발음 표기("have a nice day" → "해버 나이스 데이").
///
/// CMU 발음 사전(카네기멜런대, BSD 라이선스, `assets/cmudict.txt.gz`, 약 12만 단어)으로 발음기호를 찾고,
/// 발음기호를 한글로 옮긴다. 사전에 없는 단어(이름 등)는 철자 규칙으로 대충 읽는다.
/// 외래어 표기법이 아니라 **미국 사람이 실제로 내는 소리**에 가깝게 적는다(meet → 미트, please → 플리즈).
/// 미국식 규칙: 모음 사이 t는 굴러서 ㄹ(water → 워러, city → 씨리), nt 뒤 약모음이면 t가 빠짐(twenty → 트웨니),
/// 문장 속에서는 자음으로 끝나는 단어와 모음으로 시작하는 단어를 이어 읽는다(Can I → 캐나이, get up → 게럽).
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
  /// 띄어쓰기만 있는 사이(쉼표·마침표 없음)에서 자음 끝 + 모음 시작이면 이어 읽어 한 덩어리로 적는다.
  String sentence(String text) {
    if (_dict == null) return '';
    final t = text.replaceAll('’', "'");
    final matches = RegExp(
      r"[A-Za-z0-9']+",
    ).allMatches(t).where((m) => m.group(0)!.replaceAll("'", '').isNotEmpty).toList();
    if (matches.isEmpty) return '';
    if (matches.length == 1) return word(matches.first.group(0)!);
    final words = [for (final m in matches) m.group(0)!];
    // 단어마다 발음기호(이어 읽기 가능) 또는 고정 표기
    final phones = <List<String>?>[];
    final fixed = <String?>[];
    for (var i = 0; i < words.length; i++) {
      final key = _key(words[i]);
      List<String>? ph;
      String? f;
      if (key.isEmpty) {
        f = '';
      } else if (RegExp(r'^\d+$').hasMatch(key)) {
        f = key;
      } else if (key == 'the') {
        // 모음 앞 the는 "디"
        ph = i + 1 < words.length && _startsWithVowel(words[i + 1]) ? const ['DH', 'IY0'] : const ['DH', 'AH0'];
      } else if (_weakForms.containsKey(key)) {
        ph = _weakForms[key]; // 문장 속 기능어는 약하게(an → 언, a → 어)
      } else if (_overrides.containsKey(key)) {
        f = _overrides[key];
      } else {
        ph = _phoneOverrides[key] ?? _dict![key] ?? spellToPhones(key);
      }
      phones.add(ph);
      fixed.add(f);
    }
    final out = <String>[];
    List<String>? group;
    void flush() {
      if (group != null) out.add(phonesToHangul(group!));
      group = null;
    }

    for (var i = 0; i < words.length; i++) {
      final ph = phones[i];
      if (ph == null) {
        flush();
        if (fixed[i]!.isNotEmpty) out.add(fixed[i]!);
        continue;
      }
      final gap = i == 0 ? '' : t.substring(matches[i - 1].end, matches[i].start);
      final g = group;
      if (g != null &&
          ph.isNotEmpty &&
          RegExp(r'^\s+$').hasMatch(gap) &&
          _linkWords.contains(_key(words[i])) &&
          _canLink(g, ph)) {
        group = [..._linkEnd(g), _wb, ...ph];
      } else {
        flush();
        group = List.of(ph);
      }
    }
    flush();
    return out.where((x) => x.isNotEmpty).join(' ');
  }

  String _key(String w) => w.toLowerCase().replaceAll(RegExp(r"^'+|'+$"), '');

  bool _startsWithVowel(String w) {
    final key = _key(w);
    final ph = _phoneOverrides[key] ?? _dict?[key];
    if (ph != null && ph.isNotEmpty) return _isVowel(_strip(ph.first));
    return RegExp('^[aeiouAEIOU]').hasMatch(w);
  }

  /// 사전 발음기호(없으면 null).
  List<String>? dictPhones(String key) => _dict?[key];

  /// 단어 하나를 한글로.
  String word(String w) {
    final key = w.toLowerCase().replaceAll(RegExp(r"^'+|'+$"), '');
    if (key.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(key)) return key;
    return _cache[key] ??= () {
      final o = _overrides[key];
      if (o != null) return o;
      final phones = _phoneOverrides[key] ?? _dict?[key] ?? spellToPhones(key);
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

// 규칙으로 어색하게 나오는 아주 흔한 단어는 직접 적는다(이 단어들은 이어 읽기를 하지 않는다).
const _overrides = <String, String>{
  'good': '굿',
  'and': '앤드',
  'okay': '오케이',
  'ok': '오케이',
  'coffee': '커피',
  'sorry': '쏘리',
  'hello': '헬로우',
  // 사전에는 "라테이"처럼 나오지만 실제로는 끝 모음을 짧게 말하는 외래어
  'latte': '라테',
  'lattes': '라테스',
  'cafe': '카페',
  'café': '카페',
  'pizza': '피자',
};

// 사전 발음기호 대신 쓸 발음기호(미국에서 실제로 흔한 소리). 이어 읽기는 그대로 된다.
const _phoneOverrides = <String, List<String>>{
  'what': ['W', 'AA1', 'T'], // 왓(What is → 와리즈)
  'was': ['W', 'AH1', 'Z'], // 워즈
  'your': ['Y', 'UH1', 'R'], // 유어
};

// 문장 속에서 약하게 소리 나는 기능어(약형). 단어 하나만 있으면 사전 소리(an → 앤, to → 투).
const _weakForms = <String, List<String>>{
  'a': ['AH0'], // 어
  'an': ['AH0', 'N'], // 언
  'of': ['AH0', 'V'], // 어브
  'to': ['T', 'AH0'], // 터
};

String _strip(String p) => p.replaceAll(RegExp(r'\d'), '');

/// 이어 읽은 덩어리 안의 단어 경계 표시(소리는 없음)
const _wb = '#';

/// 앞 단어에 붙여 이어 읽는 짧은 기능어(Can I → 캐나이, get up → 게럽, is it → 이짓).
/// 내용어(iced, early…)는 붙이지 않는다: 소리는 이어져도 한글로는 어느 단어인지 알아보기 어려워서.
const _linkWords = {
  'a', 'an', 'i', 'it', 'is', 'am', 'are', 'at', 'in', 'on', 'of', 'up', 'out', 'us', 'if', 'or', 'as', //
  'it\'s', 'i\'m', 'i\'ll', 'off', 'all', 'about', 'again', 'away', 'our',
};

/// 앞 단어가 "모음 + 자음 하나"로 끝나고 뒤 단어가 모음으로 시작하면 이어 읽는다.
/// 자음이 겹친 끝(walks, doesn't), r, sh·ch·th·ng 같은 소리는 이어 적으면 낯설어서 붙이지 않는다.
bool _canLink(List<String> prev, List<String> next) {
  if (prev.length < 2 || next.isEmpty) return false;
  final last = _strip(prev.last);
  if (_isVowel(last) || !_isVowel(_strip(prev[prev.length - 2])) || !_isVowel(_strip(next.first))) return false;
  return const {'P', 'T', 'K', 'B', 'D', 'G', 'F', 'V', 'S', 'Z', 'M', 'N', 'L'}.contains(last);
}

/// 이어 읽을 때 앞 단어 끝 t: 모음 뒤면 굴러서 ㄹ(get up → 게럽), nt면 t가 빠짐(want it → 워닛).
List<String> _linkEnd(List<String> prev) {
  final n = prev.length;
  if (n >= 2 && _strip(prev.last) == 'T') {
    final before = _strip(prev[n - 2]);
    if (_isVowel(before)) return [...prev.sublist(0, n - 1), 'DX'];
    if (before == 'N' && n >= 3 && _isVowel(_strip(prev[n - 3]))) return prev.sublist(0, n - 1);
  }
  return prev;
}

/// 단어 안의 미국식 소리 변화.
/// - 모음 뒤 t + 약한 모음 → 굴리는 소리 DX(water → 워러, city → 씨리, little → 리를)
/// - 모음+nt + 약한 어/이 → t가 빠짐(twenty → 트웨니, center → 세너)
List<String> _americanize(List<String> raw) {
  final out = <String>[];
  for (var i = 0; i < raw.length; i++) {
    final p = raw[i];
    final next = i + 1 < raw.length ? raw[i + 1] : null;
    final weakNext = next != null && _isVowel(_strip(next)) && next.endsWith('0');
    if (_strip(p) == 'T' && weakNext && i > 0) {
      final prev = _strip(raw[i - 1]);
      if (_isVowel(prev)) {
        out.add('DX');
        continue;
      }
      if (prev == 'N' &&
          i > 1 &&
          _isVowel(_strip(raw[i - 2])) &&
          const {'AH', 'ER', 'IY', 'IH'}.contains(_strip(next))) {
        continue;
      }
    }
    out.add(p);
  }
  return out;
}

// ---- 발음기호(ARPAbet) → 한글 ----

const _cho = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
const _jung = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'];
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
  String get text =>
      String.fromCharCode(0xAC00 + (_cho.indexOf(cho) * 21 + _jung.indexOf(jung)) * 28 + _jong.indexOf(jong));
}

// 모음 → 한글 모음들(이중모음은 두 글자: AY → 아이)
const _vowels = <String, List<String>>{
  'AA': ['ㅏ'],
  'AE': ['ㅐ'],
  'AH': ['ㅓ'],
  'AO': ['ㅗ'],
  'OH': ['ㅗ'], // 영국식 짧은 o(hot, stop) — 짧은 모음이라 받침이 붙는다
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
// AO(talk, dog)는 넣지 않는다: talk → 토크, dog → 도그가 한국에서 익숙한 표기.
const _shortVowels = {'AE', 'EH', 'IH', 'UH', 'AH', 'AA', 'OH'};

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
  'DX': 'ㄹ', // 미국식 굴리는 t(water → 워러)
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
String phonesToHangul(List<String> raw, {bool american = true}) {
  // 단어 경계(#)는 빼고, 어느 소리가 단어 첫소리인지만 기억한다.
  // 미국식 소리 변화는 단어마다 따로 적용한다(단어 사이 t는 이어 읽을 때 이미 처리됨).
  final wordStart = <int>{};
  final clean = <String>[];
  var seg = <String>[];
  void addSeg() {
    clean.addAll(american ? _americanize(seg) : seg);
    seg = [];
  }

  for (final p in raw) {
    if (p == _wb) {
      addSeg();
      wordStart.add(clean.length);
    } else {
      seg.add(p);
    }
  }
  addSeg();
  raw = clean;
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
      // s·z·t·d·v 뒤 약한 "언" 끝소리는 "은"(seven → 세븐, lesson → 레슨, doesn't → 더즌트)
      if (p == 'AH' &&
          stress0[i] &&
          next == 'N' &&
          (i + 2 == ph.length || !_isVowel(ph[i + 2])) &&
          i > 0 &&
          !wordStart.contains(i) &&
          const {'S', 'Z', 'T', 'D', 'V'}.contains(ph[i - 1])) {
        js = ['ㅡ'];
      }
      var first = js.first;
      if (glide == 'W') first = _wGlide[first] ?? first;
      if (glide == 'Y') first = _yGlide[first] ?? first;
      if (glide == 'SH') first = _shGlide[first] ?? first;
      final cho = pendingOnset ?? 'ㅇ';
      // L이 초성이면 앞 글자에 ㄹ 받침을 더한다(please → 플리즈, hello → 헐로우)
      if (cho == 'ㄹ' && glide == null && i > 0 && ph[i - 1] == 'L' && out.isNotEmpty && out.last.jong.isEmpty) {
        out.last.jong = 'ㄹ';
      }
      out.add(_Syl(cho, first));
      for (final j in js.skip(1)) {
        out.add(_Syl('ㅇ', j));
      }
      pendingOnset = null;
      glide = null;
      // 모음 앞 er은 r 소리가 다음 모음에 붙는다(every → 에버리, hurry → 허리)
      if (p == 'ER' && next != null && _isVowel(next)) pendingOnset = 'ㄹ';
      continue;
    }
    // 자음
    final nextIsVowel = next != null && _isVowel(next);
    final nextIsGlideVowel = (next == 'W' || next == 'Y') && i + 2 < ph.length && _isVowel(ph[i + 2]);
    if (p == 'W' || p == 'Y') {
      if (nextIsVowel) {
        glide = p;
      } else if (p == 'W') {
        out.add(_Syl('ㅇ', 'ㅜ'));
      }
      continue;
    }
    // p/k/b/g/f + l/r + 모음은 한 덩어리 첫소리(replied → 리플라이드)
    final clusterNext =
        (next == 'L' || next == 'R') && i + 2 < ph.length && _isVowel(ph[i + 2]) && p != 'L' && p != 'R';
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
    // 짧은 모음 뒤 p/t/k/g/b는 받침(cat → 캣, stop → 스탑, bag → 백, job → 잡)
    if (canJong && !clusterNext && _shortVowels.contains(prev) && const {'P', 'T', 'K', 'G', 'B'}.contains(p)) {
      last.jong = {'P': 'ㅂ', 'T': 'ㅅ', 'K': 'ㄱ', 'G': 'ㄱ', 'B': 'ㅂ'}[p]!;
      continue;
    }
    // 미국식: 끝의 p/t/k는 터뜨리지 않고 삼킨다 → 긴 모음 뒤에서도 받침(night → 나잇, like → 라익, meet → 밋)
    if (canJong && !clusterNext && const {'P', 'T', 'K'}.contains(p)) {
      last.jong = {'P': 'ㅂ', 'T': 'ㅅ', 'K': 'ㄱ'}[p]!;
      continue;
    }
    // "아우" 뒤 t/p도 받침(out → 아웃, about → 어바웃)
    if (canJong && prev == 'AW' && (p == 'T' || p == 'P')) {
      last.jong = p == 'T' ? 'ㅅ' : 'ㅂ';
      continue;
    }
    // th 다음에 r이 오면 "쓰"(three → 쓰리, throw → 쓰로우)
    if (p == 'TH' && next == 'R') {
      out.add(_Syl('ㅆ', 'ㅡ'));
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

// ---- 미국식 / 영국식 비교 ----

/// 한 단어의 미국식·영국식 한글 발음과 차이 설명.
class AccentCompare {
  AccentCompare(this.us, this.uk, this.notes);
  final String us;
  final String uk;
  final List<String> notes; // 다른 점(한국어). 비어 있으면 거의 같음.
  bool get same => notes.isEmpty;
}

extension AccentCompareX on HangulPron {
  /// 단어 하나의 미국식·영국식 비교. 사전을 못 읽었으면 null.
  AccentCompare? compare(String w) {
    final key = w.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r"^'+|'+$"), '');
    if (!isReady || key.isEmpty || RegExp(r'^\d+$').hasMatch(key)) return null;
    final us = _phoneOverrides[key] ?? dictPhones(key) ?? spellToPhones(key);
    final r = britishPhones(key, us);
    final usHangul = word(key);
    var ukHangul = phonesToHangul(r.phones, american: false);
    final notes = <String>[];
    final am = _americanize(us);
    if (r.lexical) notes.add('이 단어는 미국과 영국이 읽는 법 자체가 달라요.');
    if (am.contains('DX')) {
      notes.add('t 소리: 미국식은 모음 사이 t를 혀로 살짝 튕겨 ‘ㄹ’처럼(굴리는 t), 영국식은 ‘ㅌ’를 또렷하게 내요.');
    }
    if (am.length < us.length) notes.add('nt 소리: 미국식은 n 뒤의 t를 거의 빼고 말하고, 영국식은 t를 살려요.');
    if (r.oVowel) notes.add('o 소리: 미국식은 입을 크게 벌린 ‘아’, 영국식은 입술을 둥글게 모은 짧은 ‘오’에 가까워요.');
    if (r.bath) notes.add('a 소리: 미국식은 ‘애’, 영국식은 입을 크게 벌린 긴 ‘아’예요.');
    if (r.goat) notes.add('끝의 o 소리: 미국식은 ‘오우’, 영국식은 ‘어우’에 가까워요.');
    if (r.ary) notes.add('끝의 -ary·-ory: 미국식은 ‘에리·오리’로 또렷하게, 영국식은 ‘어리’로 약하게 줄여요.');
    if (r.yod) notes.add('u 소리: 미국식은 t·d·n 뒤에서 ‘우’, 영국식은 ‘유’로 읽어요.');
    if (_hasPostVocalicR(us)) {
      notes.add('r 소리: 미국식은 모음 뒤 r에서 혀끝을 뒤로 말아 ‘r’ 소리를 내고, 영국식은 r을 소리 내지 않고 앞 모음을 길게 끌어요.');
    }
    // 한글 표기를 직접 정한 단어(pizza 피자, latte 라테)는 다른 점이 없으면 영국식도 같은 표기
    if (_overrides.containsKey(key) && !r.lexical && !r.oVowel && !r.bath && !r.goat && !r.yod && !r.ary) {
      ukHangul = usHangul;
    }
    return AccentCompare(usHangul, ukHangul, notes);
  }
}

bool _hasPostVocalicR(List<String> us) {
  for (var i = 0; i < us.length; i++) {
    final p = _strip(us[i]);
    final next = i + 1 < us.length ? _strip(us[i + 1]) : null;
    final followedByVowel = next != null && _isVowel(next);
    if (p == 'ER' && !followedByVowel) return true;
    if (p == 'R' && i > 0 && _isVowel(_strip(us[i - 1])) && !followedByVowel) return true;
  }
  return false;
}

class BritishResult {
  BritishResult(this.phones);
  List<String> phones;
  bool lexical = false, oVowel = false, bath = false, goat = false, yod = false, ary = false;
}

// 미국과 영국이 아예 다르게 읽는 흔한 단어(영국식 발음기호)
const _ukOverrides = <String, List<String>>{
  'tomato': ['T', 'AH0', 'M', 'AA1', 'T', 'AH0', 'UH0'],
  'tomatoes': ['T', 'AH0', 'M', 'AA1', 'T', 'AH0', 'UH0', 'Z'],
  'schedule': ['SH', 'EH1', 'JH', 'UW0', 'L'],
  'either': ['AY1', 'DH', 'ER0'],
  'neither': ['N', 'AY1', 'DH', 'ER0'],
  'vitamin': ['V', 'IH1', 'T', 'AH0', 'M', 'IH0', 'N'],
  'vitamins': ['V', 'IH1', 'T', 'AH0', 'M', 'IH0', 'N', 'Z'],
  'garage': ['G', 'AE1', 'R', 'AA0', 'ZH'],
  'privacy': ['P', 'R', 'IH1', 'V', 'AH0', 'S', 'IY0'],
  'leisure': ['L', 'EH1', 'ZH', 'ER0'],
  'herb': ['HH', 'ER1', 'B'],
  'herbs': ['HH', 'ER1', 'B', 'Z'],
  'mobile': ['M', 'OW1', 'B', 'AY2', 'L'],
  'banana': ['B', 'AH0', 'N', 'AA1', 'N', 'AH0'],
  'bananas': ['B', 'AH0', 'N', 'AA1', 'N', 'AH0', 'Z'],
  'missile': ['M', 'IH1', 'S', 'AY2', 'L'],
  'advertisement': ['AH0', 'D', 'V', 'ER1', 'T', 'IH0', 'S', 'M', 'AH0', 'N', 'T'],
};

// 영국식에서 a를 "아"로 읽는 흔한 단어(trap-bath 구별)
const _bathWords = {
  'ask', 'asks', 'asked', 'after', 'afternoon', 'answer', 'answers', 'aunt', 'bath', 'bathroom', 'basket', //
  'branch', "can't", 'castle', 'chance', 'class', 'classes', 'classroom', 'dance', 'dancing', 'demand',
  'example', 'fast', 'faster', 'glass', 'glasses', 'grass', 'half', 'last', 'laugh', 'master', 'pass',
  'passed', 'past', 'path', 'plant', 'plants', 'rather', 'staff', 'task', 'france', 'advance', 'command',
  'calf', 'craft', 'draft', 'graph', 'nasty', 'disaster', 'photograph', 'afterwards', 'castles',
};

/// 미국식 발음기호 → 영국식(표준 영국 발음, RP) 대략. 철자를 함께 본다.
BritishResult britishPhones(String key, List<String> us) {
  final over = _ukOverrides[key];
  if (over != null) return BritishResult(List.of(over))..lexical = true;
  final r = BritishResult(List.of(us));
  final ph = r.phones;
  // 철자 모음 묶음과 소리 모음을 순서대로 맞춘다(개수가 같을 때만).
  var spell = key.replaceAll(RegExp("[^a-z]"), '');
  if (spell.length > 3 && RegExp(r'[^aeiou]e$').hasMatch(spell)) spell = spell.substring(0, spell.length - 1);
  final groups = [
    for (final m in RegExp(r'[aeiou]+w?|(?<=[^aeiou])y(?![aeiou])').allMatches(spell))
      (text: m.group(0)!, before: m.start > 0 ? spell[m.start - 1] : ''),
  ];
  final vowelIdx = [
    for (var i = 0; i < ph.length; i++)
      if (_isVowel(_strip(ph[i]))) i,
  ];
  final aligned = groups.length == vowelIdx.length;
  String stressOf(String p) => p.replaceAll(RegExp(r'[A-Z]'), '');
  for (var k = vowelIdx.length - 1; k >= 0; k--) {
    final i = vowelIdx[k];
    final v = _strip(ph[i]);
    final st = stressOf(ph[i]);
    final g = aligned ? groups[k] : null;
    if (v == 'AA' &&
        g != null &&
        (g.text == 'o' || (g.text == 'a' && (g.before == 'w' || key.startsWith('wh') || key.contains('qua'))))) {
      ph[i] = 'OH$st'; // hot, stop, want, what
      r.oVowel = true;
    } else if (v == 'AE' && st == '1' && _bathWords.contains(key)) {
      ph[i] = 'AA$st';
      r.bath = true;
    } else if (v == 'OW' && i == ph.length - 1) {
      ph
        ..removeAt(i)
        ..insertAll(i, ['AH$st', 'UH0']); // go → 거우
      r.goat = true;
    } else if (v == 'UW' &&
        st != '0' &&
        g != null &&
        const {'u', 'ew', 'eu', 'ue', 'ui'}.contains(g.text) &&
        i > 0 &&
        const {'T', 'D', 'N'}.contains(_strip(ph[i - 1]))) {
      ph.insert(i, 'Y'); // new → 뉴, student → 스튜던트
      r.yod = true;
    }
  }
  // -ary/-ory 끝은 영국식에서 약하게(dictionary → 딕셔너리)
  final n = ph.length;
  if (n >= 3 && ph[n - 1] == 'IY0' && _strip(ph[n - 2]) == 'R' && (ph[n - 3] == 'EH2' || ph[n - 3] == 'AO2')) {
    ph[n - 3] = 'AH0';
    r.ary = true;
  }
  return r;
}
