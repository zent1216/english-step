/// 노래 제목으로 가사(LRCLIB)와 유튜브 영상을 찾는다.
///
/// 가사는 앱에 넣어 배포하지 않고, 사용자가 검색할 때 그때그때 받아온다.
/// 둘 다 API 키가 필요 없어 운영 비용이 0원이다.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'models.dart';

class LyricsResult {
  const LyricsResult({
    required this.track,
    required this.artist,
    required this.duration,
    this.synced,
    this.plain,
  });
  final String track;
  final String artist;
  final double duration; // 초
  final String? synced; // LRC 형식(시간 정보 포함)
  final String? plain;

  bool get hasSync => synced != null && synced!.trim().isNotEmpty;

  /// 연습 화면에서 쓸 소절 목록. 시간 정보가 있으면 그대로, 없으면 4초 간격 임시 타이밍.
  List<LyricLine> toLines() => hasSync ? parseLrc(synced!) : parseLyrics(plain ?? '');

  factory LyricsResult.fromJson(Map<String, dynamic> j) => LyricsResult(
        track: (j['trackName'] as String?) ?? '',
        artist: (j['artistName'] as String?) ?? '',
        duration: (j['duration'] as num?)?.toDouble() ?? 0,
        synced: j['syncedLyrics'] as String?,
        plain: j['plainLyrics'] as String?,
      );
}

/// LRCLIB(lrclib.net) 공개 가사 데이터베이스 검색. 시간 정보가 있는 가사를 앞에 둔다.
Future<List<LyricsResult>> searchLyrics(String query) async {
  final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
  final res = await http.get(uri, headers: {
    'User-Agent': 'english_step/1.0 (https://github.com/zent1216/leakcall)',
  }).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) throw Exception('가사 검색 실패 (${res.statusCode})');

  final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((j) => j['instrumental'] != true)
      .map(LyricsResult.fromJson)
      .where((r) => r.hasSync || (r.plain?.trim().isNotEmpty ?? false))
      .toList();

  // 같은 곡이 여러 번 올라와 있는 경우가 많아 (제목, 가수, 길이 반올림)이 같으면 하나만 남긴다.
  final seen = <String>{};
  final unique = [
    for (final r in list)
      if (seen.add('${r.track.toLowerCase()}|${r.artist.toLowerCase()}|${r.duration.round()}'))
        r,
  ];
  unique.sort((a, b) => (b.hasSync ? 1 : 0) - (a.hasSync ? 1 : 0));
  return unique;
}

final _lrcTag = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');

/// LRC 가사(`[mm:ss.xx]가사`)를 소절 목록으로 바꾼다. 빈 줄은 건너뛴다.
List<LyricLine> parseLrc(String lrc) {
  final out = <LyricLine>[];
  for (final row in lrc.split('\n')) {
    final tags = _lrcTag.allMatches(row).toList();
    if (tags.isEmpty) continue;
    final text = row.substring(tags.last.end).trim();
    if (text.isEmpty) continue;
    // 후렴처럼 한 줄에 시각이 여러 개 붙은 경우도 있다.
    for (final m in tags) {
      final t = int.parse(m.group(1)!) * 60 + double.parse(m.group(2)!);
      // [표현|뜻] 표시 문법과 겹치지 않게 대괄호는 지운다.
      out.add(LyricLine(t: t, en: text.replaceAll(RegExp(r'[\[\]]'), '')));
    }
  }
  out.sort((a, b) => a.t.compareTo(b.t));
  return out;
}

class VideoResult {
  const VideoResult({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
  });
  final String id;
  final String title;
  final String author;
  final Duration? duration;

  /// 가사 길이와의 차이(초). 길이를 모르면 null.
  double? diffFrom(double seconds) =>
      duration == null || seconds <= 0 ? null : (duration!.inMilliseconds / 1000 - seconds).abs();
}

// 공식 뮤직비디오는 외부 재생이 막힌 경우가 많고, 앞뒤에 영상만 있는 구간이 있어 가사와 어긋난다.
final _mvWords = RegExp(r'official\s*(music\s*)?video|\bm/?v\b|뮤직비디오', caseSensitive: false);
final _goodWords = RegExp(r'lyric|audio|가사', caseSensitive: false);
// 원곡이 아닌 영상(반주, 커버, 강좌, 라이브 등)은 따라 부르기용으로 맞지 않는다.
final _badWords = RegExp(
  r'karaoke|instrumental|cover|how to play|guitar|piano|ukulele|tutorial|chords|lesson|'
  r'reaction|live|tribute|revival|remix|sped up|slowed|8d|노래방|반주|커버|강좌',
  caseSensitive: false,
);

/// 유튜브 검색. [targetSeconds](가사의 곡 길이)와 길이가 비슷하고,
/// 가사·오디오 영상인 것을 앞에 둔다.
Future<List<VideoResult>> searchVideos(String query, {double targetSeconds = 0}) async {
  final yt = YoutubeExplode();
  try {
    final found = await yt.search.search('$query lyrics').timeout(const Duration(seconds: 20));
    final videos = [
      for (final v in found.take(15))
        if (!v.isLive)
          VideoResult(id: v.id.value, title: v.title, author: v.author, duration: v.duration),
    ];
    double score(VideoResult v) {
      final diff = v.diffFrom(targetSeconds);
      var s = diff == null ? 15.0 : diff.clamp(0, 60).toDouble();
      if (_mvWords.hasMatch(v.title)) s += 20;
      if (_badWords.hasMatch(v.title)) s += 40;
      if (_goodWords.hasMatch(v.title)) s -= 5;
      return s;
    }

    // 원래 검색 순위도 조금 반영해서, 비슷한 점수면 위에 있던 영상이 먼저 오게 한다.
    final ranked = [
      for (var i = 0; i < videos.length; i++) (v: videos[i], s: score(videos[i]) + i * 0.5),
    ]..sort((a, b) => a.s.compareTo(b.s));
    return ranked.map((e) => e.v).toList();
  } finally {
    yt.close();
  }
}
