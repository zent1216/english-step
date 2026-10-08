import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'song_editor_screen.dart';
import 'song_search_screen.dart';
import 'song_practice_screen.dart';

class SongListScreen extends StatelessWidget {
  const SongListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('팝송 연습')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.search),
        label: const Text('노래 찾기'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SongSearchScreen()),
        ),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final songs = state.allSongs;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: songs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  '노래 제목을 검색하면 가사와 유튜브 영상을 자동으로 찾아 채워줘요. '
                  '가사는 앱에 들어있지 않고, 검색할 때 공개 가사 데이터베이스(LRCLIB)에서 받아와요.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                );
              }
              return _SongTile(song: songs[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = [
      '${song.lines.length}소절',
      song.youtubeId.isNotEmpty ? '유튜브' : '영상 없음',
      song.synced ? '타이밍 맞춤' : '임시 타이밍',
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(song.youtubeId.isNotEmpty ? Icons.smart_display : Icons.lyrics),
        ),
        title: Text(song.title),
        subtitle: Text(info),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SongPracticeScreen(song: song)),
        ),
        trailing: song.isDemo
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SongEditorScreen(song: song)),
                    );
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('노래 삭제'),
                        content: Text('"${song.title}"을(를) 삭제할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) AppState.instance.removeSong(song);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
      ),
    );
  }
}
