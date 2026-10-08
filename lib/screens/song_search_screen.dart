import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../song_search.dart';
import '../theme.dart';
import 'song_editor_screen.dart';
import 'song_practice_screen.dart';

/// 노래 찾기: 제목 입력 → 가사 고르기 → 영상 고르기 → 저장하고 바로 연습.
class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({super.key});

  @override
  State<SongSearchScreen> createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen> {
  final _query = TextEditingController();
  bool _loading = false;
  String? _error;
  List<LyricsResult>? _lyrics;
  LyricsResult? _picked; // 고른 가사
  List<VideoResult>? _videos;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _searchLyrics() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _lyrics = null;
      _picked = null;
      _videos = null;
    });
    try {
      final r = await searchLyrics(q);
      if (!mounted) return;
      setState(() {
        _lyrics = r;
        if (r.isEmpty) _error = '가사를 찾지 못했어요. 영어 제목과 가수 이름을 같이 넣어보세요.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '가사 검색에 실패했어요. 인터넷 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLyrics(LyricsResult r) async {
    setState(() {
      _picked = r;
      _videos = null;
      _loading = true;
      _error = null;
    });
    try {
      final v = await searchVideos('${r.artist} ${r.track}', targetSeconds: r.duration);
      if (!mounted) return;
      setState(() {
        _videos = v;
        if (v.isEmpty) _error = '영상을 찾지 못했어요. 영상 없이 가사만으로 연습할 수 있어요.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = '영상 검색에 실패했어요. 영상 없이 가사만으로 연습할 수 있어요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save(VideoResult? video) {
    final r = _picked!;
    final lines = r.toLines();
    if (lines.isEmpty) {
      setState(() => _error = '이 가사는 비어 있어요. 다른 결과를 골라주세요.');
      return;
    }
    final song = Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: r.artist.isEmpty ? r.track : '${r.track} - ${r.artist}',
      youtubeId: video?.id ?? '',
      lines: lines,
      end: r.duration > 0 ? r.duration : lines.last.t + 4,
      synced: r.hasSync,
    );
    AppState.instance.addSong(song);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SongPracticeScreen(song: song)),
    );
  }

  String _fmt(double s) => '${s ~/ 60}:${(s % 60).round().toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('노래 찾기'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SongEditorScreen()),
            ),
            child: const Text('직접 입력'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchLyrics(),
            decoration: InputDecoration(
              labelText: '노래 제목',
              hintText: '영어 제목 + 가수 이름이면 더 정확해요',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '검색',
                icon: const Icon(Icons.search),
                onPressed: _searchLyrics,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_picked == null) ..._lyricsList(scheme) else ..._videoList(scheme),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
        ],
      ),
    );
  }

  List<Widget> _lyricsList(ColorScheme scheme) {
    final list = _lyrics;
    if (list == null || list.isEmpty) return const [];
    return [
      Text('1. 가사 고르기', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final r in list.take(15))
              ListTile(
                title: Text(r.track),
                subtitle: Text(r.artist),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmt(r.duration), style: const TextStyle(fontFamily: monoFont)),
                    Text(
                      r.hasSync ? '시간 맞춤' : '가사만',
                      style: TextStyle(
                        fontSize: 11,
                        color: r.hasSync ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                onTap: () => _pickLyrics(r),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _videoList(ColorScheme scheme) {
    final r = _picked!;
    final videos = _videos ?? const <VideoResult>[];
    return [
      Card(
        color: scheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.lyrics),
          title: Text(r.track),
          subtitle: Text(
              '${r.artist} · ${_fmt(r.duration)} · ${r.hasSync ? '시간 맞춤 가사' : '가사만(타이밍은 직접)'}'),
          trailing: TextButton(
            onPressed: () => setState(() {
              _picked = null;
              _videos = null;
              _error = null;
            }),
            child: const Text('다시 고르기'),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text('2. 영상 고르기', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(
        '곡 길이가 맞는 가사·오디오 영상을 위에 두었어요. 재생이 안 되면 연습 화면에서 다른 영상으로 바꿀 수 있어요.',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      if (videos.isNotEmpty)
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < videos.length && i < 8; i++) _videoTile(videos[i], i == 0, r),
            ],
          ),
        ),
      if (!_loading) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.music_off_outlined),
          label: const Text('영상 없이 가사만으로 저장'),
          onPressed: () => _save(null),
        ),
      ],
    ];
  }

  Widget _videoTile(VideoResult v, bool best, LyricsResult r) {
    final scheme = Theme.of(context).colorScheme;
    final diff = v.diffFrom(r.duration);
    final d = v.duration;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          'https://i.ytimg.com/vi/${v.id}/mqdefault.jpg',
          width: 80,
          height: 45,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Container(width: 80, height: 45, color: scheme.surfaceContainerHighest),
        ),
      ),
      title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          v.author,
          if (d != null) _fmt(d.inMilliseconds / 1000),
          if (diff != null && diff <= 3) '길이 일치',
          if (best) '추천',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _save(v),
    );
  }
}
