import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../app_state.dart';
import '../models.dart';
import '../song_search.dart';
import '../theme.dart';
import '../translate.dart';
import '../widgets/marked_text.dart';
import '../widgets/speak_check_sheet.dart';
import '../widgets/pron_text.dart';

const _rates = [0.5, 0.75, 0.9, 1.0, 1.25];
const _stageNames = ['전체', '빈칸', '첫 글자', '숨기기'];

/// 팝송 연습: 위에는 유튜브(없으면 가상 시계), 아래에는 재생 위치를 따라가는 가사.
class SongPracticeScreen extends StatefulWidget {
  const SongPracticeScreen({super.key, required this.song});
  final Song song;

  @override
  State<SongPracticeScreen> createState() => _SongPracticeScreenState();
}

class _SongPracticeScreenState extends State<SongPracticeScreen> {
  YoutubePlayerController? _yt;
  StreamSubscription<YoutubePlayerValue>? _ytSub;
  Timer? _poll;
  String? _error;

  double _pos = 0; // 현재 재생 위치(초)
  bool _playing = false;
  double _rate = 1;
  int? _loopIdx; // 한 줄 반복 중인 소절
  int _stage = 0; // 연습 단계 0~3
  bool _showKo = true;
  final _revealed = <int>{}; // 빈칸/첫 글자/숨기기 단계에서 정답을 펼친 줄
  int _trDone = 0, _trTotal = 0; // 기기 번역 진행 상황(_trTotal > 0이면 번역 중)

  // 영상이 없을 때 쓰는 가상 시계: 마지막으로 재생을 시작한 시각과 그때의 위치.
  double _vBase = 0;
  DateTime? _vStart;

  List<double>? _syncTimes; // 타이밍 맞추는 중이면 지금까지 찍은 시각들

  late final List<GlobalKey> _keys;
  int _lastScrolled = -1;

  Song get song => widget.song;
  List<LyricLine> get lines => song.lines;
  double get _end => song.end > 0 ? song.end : lines.last.t + 4;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(lines.length, (_) => GlobalKey());
    _initVideo();
    _poll = Timer.periodic(const Duration(milliseconds: 150), (_) => _tick());
  }

  void _initVideo() {
    if (song.youtubeId.isEmpty) return;
    _yt = YoutubePlayerController.fromVideoId(
      videoId: song.youtubeId,
      params: const YoutubePlayerParams(
        showFullscreenButton: false,
        strictRelatedVideos: true,
        enableCaption: false,
      ),
    );
    _ytSub = _yt!.stream.listen((v) {
      if (!mounted) return;
      setState(() {
        _playing = v.playerState == PlayerState.playing;
        if (v.error != YoutubeError.none) _error = _errorText(v.error);
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ytSub?.cancel();
    _yt?.close();
    super.dispose();
  }

  String _errorText(YoutubeError e) => switch (e) {
        YoutubeError.notEmbeddable || YoutubeError.sameAsNotEmbeddable =>
          '이 영상은 앱에서 재생할 수 없어요. 가사 영상이나 다른 업로드를 찾아보세요.',
        YoutubeError.videoNotFound || YoutubeError.cannotFindVideo =>
          '영상을 찾을 수 없어요. 주소를 확인해 주세요.',
        _ => '영상을 재생하지 못했어요. 인터넷 연결을 확인해 주세요.',
      };

  // ---- 재생 제어 ----

  double get _virtualPos => _vStart == null
      ? _vBase
      : _vBase + DateTime.now().difference(_vStart!).inMilliseconds / 1000 * _rate;

  Future<double> _readPos() async => _yt != null ? await _yt!.currentTime : _virtualPos;

  double _lineEnd(int i) {
    if (i + 1 < lines.length) return lines[i + 1].t;
    if (_yt != null) {
      final d = _yt!.value.metaData.duration.inMilliseconds / 1000;
      return d > lines[i].t ? d : lines[i].t + 6;
    }
    return _end;
  }

  Future<void> _tick() async {
    if (!_playing) return;
    final p = await _readPos();
    if (!mounted || !_playing) return;

    final li = _loopIdx;
    if (li != null && _syncTimes == null &&
        (p >= _lineEnd(li) - 0.05 || p < lines[li].t - 0.3)) {
      _seek(lines[li].t);
      return;
    }
    if (_yt == null && p >= _end) {
      _vBase = _end;
      _vStart = null;
      _playing = false;
    }
    setState(() => _pos = math.min(p, _yt == null ? _end : p));
    _autoScroll();
  }

  void _seek(double t) {
    t = math.max(0, t);
    if (_yt != null) {
      _yt!.seekTo(seconds: t, allowSeekAhead: true);
    } else {
      _vBase = t;
      if (_vStart != null) _vStart = DateTime.now();
    }
    setState(() => _pos = t);
    _autoScroll();
  }

  void _play() {
    if (_yt != null) {
      _yt!.playVideo();
      return;
    }
    if (_vBase >= _end) _vBase = 0;
    setState(() {
      _vStart = DateTime.now();
      _playing = true;
    });
  }

  void _pause() {
    if (_yt != null) {
      _yt!.pauseVideo();
      return;
    }
    setState(() {
      _vBase = _virtualPos;
      _vStart = null;
      _playing = false;
    });
  }

  void _setRate(double r) {
    if (_yt != null) {
      _yt!.setPlaybackRate(r);
    } else if (_vStart != null) {
      _vBase = _virtualPos;
      _vStart = DateTime.now();
    }
    setState(() => _rate = r);
  }

  /// 영상 재생이 막혔을 때 영상 없이 가사만 가상 시계로 진행한다.
  void _dropVideo() {
    _ytSub?.cancel();
    _yt?.close();
    setState(() {
      _yt = null;
      _error = null;
      _playing = false;
      _vBase = _pos;
      _vStart = null;
    });
  }

  /// 다른 유튜브 영상으로 바꾼다(재생이 막혔거나 가사와 안 맞을 때).
  Future<void> _changeVideo() async {
    final picked = await showModalBottomSheet<VideoResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _VideoPickerSheet(song: song),
    );
    if (picked == null || !mounted) return;
    _ytSub?.cancel();
    _yt?.close();
    song.youtubeId = picked.id;
    AppState.instance.updateSong(song);
    setState(() {
      _yt = null;
      _error = null;
      _playing = false;
      _pos = 0;
      _vBase = 0;
      _vStart = null;
      _lastScrolled = -1;
    });
    _initVideo();
    setState(() {});
  }

  bool get _missingKo => lines.any((l) => l.ko.trim().isEmpty);

  /// 해석이 빈 줄을 기기 번역(ML Kit)으로 채운다. 처음 한 번은 번역 모델을 받는다.
  Future<void> _fillTranslation() async {
    if (!await translationModelsReady()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('해석 자동 채우기'),
          content: const Text(
            '휴대폰 안에서 무료로 번역해요. 처음 한 번만 번역 모델(약 60MB)을 내려받아요. '
            '와이파이에서 받는 걸 권장해요.\n\n'
            '기계 번역이라 가사의 비유는 어색할 수 있어요. 노래 수정 화면에서 직접 고칠 수 있어요.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('받고 번역')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final targets = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].ko.trim().isEmpty) i,
    ];
    setState(() {
      _trDone = 0;
      _trTotal = targets.length;
    });
    try {
      final ko = await translateToKorean(
        [for (final i in targets) plainText(lines[i].en)],
        onProgress: (done, _) {
          if (mounted) setState(() => _trDone = done);
        },
      );
      for (var k = 0; k < targets.length; k++) {
        lines[targets[k]].ko = ko[k];
      }
      AppState.instance.updateSong(song);
      if (mounted) setState(() => _showKo = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('번역하지 못했어요. 처음에는 인터넷 연결이 필요해요.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _trTotal = 0);
    }
  }

  /// 모든 소절의 시각을 [d]초만큼 옮긴다(영상 앞부분 길이가 달라 가사가 밀릴 때).
  void _shiftAll(double d) {
    for (final l in lines) {
      l.t = math.max(0, l.t + d);
    }
    AppState.instance.updateSong(song);
    setState(() => _lastScrolled = -1);
  }

  Future<void> _showShiftSheet() {
    var total = 0.0;
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          Widget btn(double d) => OutlinedButton(
                onPressed: () {
                  _shiftAll(d);
                  setSheet(() => total += d);
                },
                child: Text('${d > 0 ? '+' : ''}$d초'),
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('싱크 조절', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text('가사가 노래보다 먼저 나오면 + (늦추기), 늦게 나오면 − (당기기)'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [btn(-1), btn(-0.5), btn(0.5), btn(1)],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '이번에 옮긴 시간: ${total > 0 ? '+' : ''}${total.toStringAsFixed(1)}초',
                    style: const TextStyle(fontFamily: monoFont),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int get _current {
    if (_syncTimes != null) return _syncTimes!.length - 1;
    var cur = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].t <= _pos + 0.05) cur = i;
    }
    return cur;
  }

  void _goLine(int i) {
    if (_syncTimes != null) return;
    i = i.clamp(0, lines.length - 1);
    if (_loopIdx != null) _loopIdx = i;
    _seek(lines[i].t);
    if (!_playing) _play();
  }

  void _toggleLoop() =>
      setState(() => _loopIdx = _loopIdx == null ? math.max(0, _current) : null);

  void _autoScroll() {
    final cur = _current;
    if (cur < 0 || cur == _lastScrolled) return;
    _lastScrolled = cur;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[cur].currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.3, duration: const Duration(milliseconds: 300));
      }
    });
  }

  // ---- 타이밍 맞추기 ----

  Future<void> _startSync() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('타이밍 맞추기'),
        content: const Text(
          '노래를 처음부터 재생해요. 각 소절이 시작되는 순간마다 아래의 큰 버튼을 눌러주세요.\n\n'
          '마지막 소절까지 누르면 저장돼요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('시작')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _syncTimes = [];
      _loopIdx = null;
      _lastScrolled = -1;
    });
    _seek(0);
    _play();
  }

  Future<void> _tapSync() async {
    final times = _syncTimes;
    if (times == null) return;
    final p = await _readPos();
    if (!mounted) return;
    setState(() => times.add(times.isEmpty ? p : math.max(p, times.last)));
    _autoScroll();
    if (times.length < lines.length) return;

    for (var i = 0; i < lines.length; i++) {
      lines[i].t = times[i];
    }
    song.end = math.max(song.end, times.last + 4);
    song.synced = true;
    AppState.instance.updateSong(song);
    setState(() => _syncTimes = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('타이밍을 저장했어요.')));
  }

  // ---- 화면 ----

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return Scaffold(
      appBar: AppBar(
        title: Text(song.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (!song.isDemo && _syncTimes == null)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'shift' => _showShiftSheet(),
                'video' => _changeVideo(),
                _ => _startSync(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'shift', child: Text('싱크 조절 (가사 밀림)')),
                PopupMenuItem(value: 'video', child: Text('다른 영상 찾기')),
                PopupMenuItem(value: 'sync', child: Text('타이밍 직접 맞추기')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: _syncTimes == null ? null : _syncBar(),
      body: Column(
        children: [
          if (_yt != null)
            YoutubePlayer(key: ValueKey(song.youtubeId), controller: _yt!)
          else
            _virtualClock(),
          if (_error != null) _errorBanner(),
          _controls(cur),
          _stageBar(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [for (var i = 0; i < lines.length; i++) _line(i, cur)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double t) =>
      '${t ~/ 60}:${(t % 60).toStringAsFixed(1).padLeft(4, '0')}';

  Widget _virtualClock() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lyrics_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('영상 없이 가사만 진행돼요',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              Text('${_fmt(_pos)} / ${_fmt(_end)}',
                  style: const TextStyle(fontFamily: monoFont)),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (_pos / _end).clamp(0, 1)),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
          ),
          Column(
            children: [
              if (!song.isDemo)
                TextButton(onPressed: _changeVideo, child: const Text('다른 영상 찾기')),
              TextButton(onPressed: _dropVideo, child: const Text('가사만 보기')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls(int cur) {
    final syncing = _syncTimes != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '이전 줄',
            icon: const Icon(Icons.skip_previous),
            onPressed: syncing ? null : () => _goLine(cur - 1),
          ),
          IconButton.filled(
            tooltip: _playing ? '일시정지' : '재생',
            iconSize: 30,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            onPressed: _playing ? _pause : _play,
          ),
          IconButton(
            tooltip: '다음 줄',
            icon: const Icon(Icons.skip_next),
            onPressed: syncing ? null : () => _goLine(cur + 1),
          ),
          IconButton(
            tooltip: '한 줄 반복',
            isSelected: _loopIdx != null,
            icon: const Icon(Icons.repeat_one),
            selectedIcon: const Icon(Icons.repeat_one_on),
            onPressed: syncing ? null : _toggleLoop,
          ),
          const Spacer(),
          if (_yt != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(_fmt(_pos), style: const TextStyle(fontFamily: monoFont)),
            ),
          PopupMenuButton<double>(
            tooltip: '재생 속도',
            initialValue: _rate,
            onSelected: _setRate,
            itemBuilder: (_) => [
              for (final r in _rates) PopupMenuItem(value: r, child: Text('$r배')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 20),
                  const SizedBox(width: 4),
                  Text('${_rate}x', style: const TextStyle(fontFamily: monoFont)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (var i = 0; i < _stageNames.length; i++)
                ButtonSegment(value: i, label: Text(_stageNames[i])),
            ],
            selected: {_stage},
            onSelectionChanged: (s) => setState(() {
              _stage = s.first;
              _revealed.clear();
            }),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('해석'),
            selected: _showKo,
            onSelected: (v) => setState(() => _showKo = v),
          ),
          const SizedBox(width: 4),
          const PronToggle(),
          if (_trTotal > 0) ...[
            const SizedBox(width: 8),
            Chip(
              avatar: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('번역 중 $_trDone/$_trTotal'),
            ),
          ] else if (_missingKo && canTranslateOnDevice && !song.isDemo) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.translate, size: 18),
              label: const Text('해석 자동 채우기'),
              onPressed: _fillTranslation,
            ),
          ],
        ],
      ),
    );
  }

  /// 빈칸 단계는 단어를 하나 걸러 지우고, 첫 글자 단계는 단어마다 첫 글자만 남긴다.
  String _mask(String s, {required bool firstLetter}) {
    var n = 0;
    return s.replaceAllMapped(RegExp(r"[A-Za-z][A-Za-z']*"), (m) {
      final w = m[0]!;
      if (firstLetter) return w[0] + '_' * (w.length - 1);
      return n++ % 2 == 1 ? '_' * w.length : w;
    });
  }

  Widget _line(int i, int cur) {
    final scheme = Theme.of(context).colorScheme;
    final l = lines[i];
    final revealed = _stage == 0 || _revealed.contains(i);
    final Widget en;
    if (revealed) {
      en = MarkedText(l.en, size: 19);
    } else if (_stage == 3) {
      en = Text('♪ · · ·', style: englishStyle(context, size: 19).copyWith(color: scheme.outline));
    } else {
      en = Text(
        _mask(plainText(l.en), firstLetter: _stage == 2),
        style: englishStyle(context, size: 19).copyWith(letterSpacing: 0.6),
      );
    }
    final showKo = l.ko.isNotEmpty && (_showKo || _stage == 3);

    return Material(
      key: _keys[i],
      color: i == cur ? currentLineColor(context) : Colors.transparent,
      child: InkWell(
        onTap: () => _goLine(i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    _fmt(l.t),
                    style: TextStyle(
                      fontFamily: monoFont,
                      fontSize: 11,
                      color: _loopIdx == i ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: _loopIdx == i ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    en,
                    if (revealed) PronText(l.en),
                    if (showKo)
                      Text(l.ko, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              // 가사 한 줄 따라 말하기. 음악과 겹치면 인식이 안 되므로 먼저 멈춘다.
              SpeakCheckButton(l.en, ko: l.ko, onBeforeOpen: _pause),
              if (_stage > 0)
                IconButton(
                  tooltip: revealed ? '가리기' : '정답 보기',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20),
                  onPressed: () =>
                      setState(() => revealed ? _revealed.remove(i) : _revealed.add(i)),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _syncBar() {
    final scheme = Theme.of(context).colorScheme;
    final next = _syncTimes!.length;
    return SafeArea(
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${next + 1} / ${lines.length}번째 소절',
                    style: const TextStyle(fontFamily: monoFont)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _syncTimes = null),
                  child: const Text('그만두기'),
                ),
              ],
            ),
            Text(
              plainText(lines[next].en),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: englishStyle(context, size: 16),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: _tapSync,
                child: const Text('이 소절 시작!', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 연습 중에 다른 유튜브 영상을 고르는 시트. 노래 제목과 곡 길이로 다시 검색한다.
class _VideoPickerSheet extends StatefulWidget {
  const _VideoPickerSheet({required this.song});
  final Song song;

  @override
  State<_VideoPickerSheet> createState() => _VideoPickerSheetState();
}

class _VideoPickerSheetState extends State<_VideoPickerSheet> {
  late final Future<List<VideoResult>> _future =
      searchVideos(widget.song.title, targetSeconds: widget.song.end);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: FutureBuilder<List<VideoResult>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = (snap.data ?? const <VideoResult>[])
                .where((v) => v.id != widget.song.youtubeId)
                .toList();
            if (snap.hasError || list.isEmpty) {
              return Center(
                child: Text(
                  snap.hasError ? '영상 검색에 실패했어요. 인터넷 연결을 확인해 주세요.' : '다른 영상을 찾지 못했어요.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              );
            }
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text('다른 영상 고르기', style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final v in list.take(10))
                  ListTile(
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
                    subtitle: Text(v.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, v),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
