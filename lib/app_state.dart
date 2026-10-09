import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'models.dart';

/// 복습 간격(일). box 0은 바로, 맞힐 때마다 다음 칸으로.
const reviewIntervalsDays = [0, 1, 3, 7, 14, 30];

/// 저장해야 하는 모든 상태(단어장, 내 노래, 진도, 설정)를 들고 있는 곳.
/// 모두 기기 안(SharedPreferences)에만 저장한다.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  SharedPreferences? _prefs;
  List<VocabItem> vocab = [];
  List<Song> songs = [];
  Set<String> doneStories = {};
  Set<String> doneSets = {}; // Lv.0 첫걸음 문장 세트 (lv0-0 ~ lv0-19)
  double speechRate = 0.9;
  bool showPron = true; // 영어 아래 한글 발음 표기
  // 따라 말하기 문장별 최고 점수(0~100). 키는 [speakKey].
  Map<String, int> speakScores = {};

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    vocab = _decodeList(p.getString('vocab'), VocabItem.fromJson);
    songs = _decodeList(p.getString('songs'), Song.fromJson);
    doneStories = (p.getStringList('doneStories') ?? []).toSet();
    doneSets = (p.getStringList('doneSets') ?? []).toSet();
    speechRate = p.getDouble('speechRate') ?? 0.9;
    showPron = p.getBool('showPron') ?? true;
    try {
      final raw = p.getString('speakScores');
      speakScores = raw == null
          ? {}
          : (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
    } catch (_) {
      speakScores = {};
    }
    notifyListeners();
  }

  static List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) f) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveVocab() =>
      _prefs?.setString('vocab', jsonEncode(vocab.map((v) => v.toJson()).toList()));
  void _saveSongs() =>
      _prefs?.setString('songs', jsonEncode(songs.map((s) => s.toJson()).toList()));

  // ---- 단어장 ----
  bool hasWord(String word) => vocab.any((v) => v.word == word);

  void addWord(String word, String gloss, String context) {
    if (hasWord(word)) return;
    vocab.insert(0, VocabItem(word: word, gloss: gloss, context: plainText(context)));
    _saveVocab();
    notifyListeners();
  }

  void removeWord(VocabItem item) {
    vocab.remove(item);
    _saveVocab();
    notifyListeners();
  }

  /// 삭제를 되돌릴 때. 복습 진도(box, dueAt)를 그대로 살린다.
  void restoreWord(VocabItem item) {
    if (hasWord(item.word)) return;
    vocab.insert(0, item);
    _saveVocab();
    notifyListeners();
  }

  List<VocabItem> dueWords() {
    final now = DateTime.now();
    return vocab.where((v) => v.isDue(now)).toList()
      ..sort((a, b) => a.box.compareTo(b.box));
  }

  /// 복습 결과 반영. 알면 간격을 넓히고, 헷갈리면 처음부터.
  void review(VocabItem item, {required bool known}) {
    if (known) {
      item.box = (item.box + 1).clamp(0, reviewIntervalsDays.length - 1);
      item.dueAt = DateTime.now()
          .add(Duration(days: reviewIntervalsDays[item.box]))
          .millisecondsSinceEpoch;
    } else {
      item.box = 0;
      // 같은 날 조금 뒤에 다시 보여준다.
      item.dueAt = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    }
    _saveVocab();
    notifyListeners();
  }

  // ---- Lv.0 첫걸음 문장 ----
  void markSetDone(String id) {
    if (doneSets.add(id)) {
      _prefs?.setStringList('doneSets', doneSets.toList());
      notifyListeners();
    }
  }

  // ---- 이야기 ----
  void markStoryDone(String id) {
    if (doneStories.add(id)) {
      _prefs?.setStringList('doneStories', doneStories.toList());
      notifyListeners();
    }
  }

  // ---- 따라 말하기 점수 ----
  /// 같은 문장이면 어디서 말했든 같은 키(학습 포인트 표시·대소문자·문장부호 무시).
  static String speakKey(String target) =>
      plainText(target).toLowerCase().replaceAll(RegExp(r"[^a-z0-9 ]"), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  int? speakScore(String target) => speakScores[speakKey(target)];

  /// 최고 점수만 남긴다.
  void recordSpeakScore(String target, int score) {
    final k = speakKey(target);
    if (k.isEmpty || (speakScores[k] ?? -1) >= score) return;
    speakScores[k] = score;
    _prefs?.setString('speakScores', jsonEncode(speakScores));
    notifyListeners();
  }

  // ---- 초기화 ----
  /// 따라 말하기 점수만 지운다.
  Future<void> resetSpeakScores() async {
    speakScores = {};
    await _prefs?.remove('speakScores');
    notifyListeners();
  }

  /// 단어장·내 노래·진도·점수·설정을 모두 지운다(음성 인식 모델 파일은 따로).
  Future<void> resetAll() async {
    await _prefs?.clear();
    vocab = [];
    songs = [];
    doneStories = {};
    doneSets = {};
    speakScores = {};
    speechRate = 0.9;
    showPron = true;
    notifyListeners();
  }

  void setShowPron(bool v) {
    showPron = v;
    _prefs?.setBool('showPron', v);
    notifyListeners();
  }

  void setSpeechRate(double r) {
    speechRate = r;
    _prefs?.setDouble('speechRate', r);
    notifyListeners();
  }

  // ---- 노래 ----
  List<Song> get allSongs => [demoSong(), ...songs];

  void addSong(Song s) {
    songs.insert(0, s);
    _saveSongs();
    notifyListeners();
  }

  void updateSong(Song s) {
    if (s.isDemo) return;
    final i = songs.indexWhere((x) => x.id == s.id);
    if (i >= 0) songs[i] = s;
    _saveSongs();
    notifyListeners();
  }

  void removeSong(Song s) {
    songs.removeWhere((x) => x.id == s.id);
    _saveSongs();
    notifyListeners();
  }
}

/// 기기 내장 음성으로 영어를 읽어준다(무료, 오프라인 가능).
class Speaker {
  Speaker._() {
    _tts.setLanguage('en-US');
    _tts.awaitSpeakCompletion(true);
  }
  static final Speaker instance = Speaker._();
  final _tts = FlutterTts();

  /// [rate]는 1.0이 보통 속도. flutter_tts는 모바일에서 0.5가 보통 속도라 변환한다.
  Future<void> speak(String text, {double rate = 1.0}) async {
    await _tts.stop();
    await _tts.setSpeechRate(kIsWeb ? rate : rate * 0.5);
    await _tts.speak(plainText(text));
  }

  Future<void> stop() => _tts.stop();
}
