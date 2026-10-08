import 'package:english_step/song_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLrc', () {
    test('시각을 초로 바꾸고 빈 줄은 건너뛴다', () {
      final lines = parseLrc('[00:01.50]First line here\n'
          '[00:04.00]\n'
          '[01:02.25] Second line \n'
          'no tag line\n');
      expect(lines.map((l) => l.t), [1.5, 62.25]);
      expect(lines.map((l) => l.en), ['First line here', 'Second line']);
    });

    test('한 줄에 시각이 여러 개면 각각 소절로 만들고 시간순 정렬', () {
      final lines = parseLrc('[00:10.00][00:30.00]Repeat me\n[00:20.00]Middle');
      expect(lines.map((l) => (l.t, l.en)), [
        (10.0, 'Repeat me'),
        (20.0, 'Middle'),
        (30.0, 'Repeat me'),
      ]);
    });

    test('가사 속 대괄호는 지운다 ([표현|뜻] 문법과 충돌 방지)', () {
      expect(parseLrc('[00:01.00]Hello [softly] world').single.en, 'Hello softly world');
    });
  });

  test('LyricsResult: 시간 정보가 없으면 4초 간격 임시 타이밍', () {
    const r = LyricsResult(track: 't', artist: 'a', duration: 10, plain: 'One\nTwo');
    expect(r.hasSync, isFalse);
    expect(r.toLines().map((l) => l.t), [0, 4]);
  });

  test('VideoResult.diffFrom', () {
    const v = VideoResult(id: 'x', title: 't', author: 'a', duration: Duration(seconds: 125));
    expect(v.diffFrom(124), 1);
    expect(v.diffFrom(0), isNull);
  });
}
