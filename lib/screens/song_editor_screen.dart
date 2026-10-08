import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

/// 내 노래 추가/수정: 제목, 유튜브 주소, 가사(한 줄에 한 소절, 해석은 " | " 뒤에).
class SongEditorScreen extends StatefulWidget {
  const SongEditorScreen({super.key, this.song});
  final Song? song; // null이면 새 노래

  @override
  State<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends State<SongEditorScreen> {
  late final _title = TextEditingController(text: widget.song?.title ?? '');
  late final _url = TextEditingController(
    text: widget.song == null || widget.song!.youtubeId.isEmpty
        ? ''
        : 'https://youtu.be/${widget.song!.youtubeId}',
  );
  late final _lyrics = TextEditingController(
    text: widget.song?.lines
            .map((l) => l.ko.isEmpty ? plainText(l.en) : '${plainText(l.en)} | ${l.ko}')
            .join('\n') ??
        '',
  );
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final url = _url.text.trim();
    final youtubeId = url.isEmpty ? '' : parseYoutubeId(url);
    final lines = parseLyrics(_lyrics.text);
    final error = title.isEmpty
        ? '제목을 입력해 주세요.'
        : url.isNotEmpty && youtubeId.isEmpty
            ? '유튜브 주소를 확인해 주세요. (예: https://youtu.be/xxxxxxxxxxx)'
            : lines.isEmpty
                ? '가사를 한 줄 이상 붙여넣어 주세요.'
                : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final old = widget.song;
    // 소절 수가 그대로면 맞춰둔 타이밍을 살린다(오타 수정 정도는 다시 맞출 필요 없게).
    final keepTiming = old != null && old.lines.length == lines.length;
    if (keepTiming) {
      for (var i = 0; i < lines.length; i++) {
        lines[i].t = old.lines[i].t;
      }
    }
    final song = Song(
      id: old?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      youtubeId: youtubeId,
      lines: lines,
      end: keepTiming ? old.end : lines.last.t + 4,
      synced: keepTiming && old.synced,
    );
    if (old == null) {
      AppState.instance.addSong(song);
    } else {
      AppState.instance.updateSong(song);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song == null ? '내 노래 추가' : '노래 수정'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: _save, child: const Text('저장')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '유튜브 주소 (없어도 돼요)',
              hintText: 'https://youtu.be/...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '공식 뮤직비디오는 앱 재생이 막힌 경우가 많아요. 안 되면 가사 영상을 찾아보세요.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _lyrics,
            minLines: 10,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: '가사',
              alignLabelWithHint: true,
              hintText: '한 줄에 한 소절씩, 해석은 | 뒤에\n\n'
                  'I fold a paper boat tonight | 오늘 밤 나는 종이배를 접어\n'
                  'And send it down the river light | 강물 빛을 따라 띄워 보내',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '처음에는 4초 간격으로 임시 타이밍이 들어가요. 연습 화면의 "타이밍 맞추기"로 노래에 맞출 수 있어요.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}
