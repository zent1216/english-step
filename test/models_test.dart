import 'package:english_step/content.dart';
import 'package:english_step/models.dart';
import 'package:english_step/sentences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lv.0 문장 데이터: 200개, 10개씩 20세트, 빈 값 없음', () async {
    final all = await loadLv0Sentences();
    expect(all, hasLength(200));
    expect(chunkSets(all), hasLength(20));
    for (final s in all) {
      expect(s.en.trim(), isNotEmpty);
      expect(s.ko.trim(), isNotEmpty);
      expect(s.src, startsWith('#'));
    }
    expect(all.map((s) => s.en.toLowerCase()).toSet(), hasLength(200), reason: '중복 문장');
  });

  group('parseMarked', () {
    test('학습 포인트와 일반 텍스트를 나눈다', () {
      final segs = parseMarked('Mina [walks into|~에 걸어 들어가다] a shop.');
      expect(segs.map((s) => s.text), ['Mina ', 'walks into', ' a shop.']);
      expect(segs[1].isMarked, isTrue);
      expect(segs[1].gloss, '~에 걸어 들어가다');
      expect(segs[0].isMarked, isFalse);
    });

    test('표시가 없으면 한 조각', () {
      final segs = parseMarked('Hello there.');
      expect(segs, hasLength(1));
      expect(segs.single.text, 'Hello there.');
    });

    test('문장 시작과 끝의 학습 포인트', () {
      final segs = parseMarked('[A minute later|1분 뒤], she [left|떠났다]');
      expect(segs.map((s) => s.text), ['A minute later', ', she ', 'left']);
    });
  });

  test('plainText는 표시를 지운다', () {
    expect(plainText('"[Can I have|~ 주시겠어요?] a latte?"'), '"Can I have a latte?"');
  });

  group('parseYoutubeId', () {
    test('여러 주소 형식', () {
      const id = 'abcDEF12_-x';
      expect(parseYoutubeId('https://www.youtube.com/watch?v=$id&t=10'), id);
      expect(parseYoutubeId('https://youtu.be/$id?si=xyz'), id);
      expect(parseYoutubeId('https://youtube.com/shorts/$id'), id);
      expect(parseYoutubeId('https://www.youtube.com/embed/$id'), id);
      expect(parseYoutubeId('  $id  '), id);
    });

    test('못 찾으면 빈 문자열', () {
      expect(parseYoutubeId('https://example.com'), '');
      expect(parseYoutubeId(''), '');
    });
  });

  group('parseLyrics', () {
    test('해석 분리, 빈 줄 무시, 4초 간격', () {
      final lines = parseLyrics('Line one | 첫 줄\n\n  Line two  \nLine three|셋째 | 줄');
      expect(lines.map((l) => l.en), ['Line one', 'Line two', 'Line three']);
      expect(lines.map((l) => l.ko), ['첫 줄', '', '셋째 줄']);
      expect(lines.map((l) => l.t), [0, 4, 8]);
    });
  });

  test('Song/VocabItem JSON 왕복', () {
    final song = Song(
      id: '1',
      title: 't',
      youtubeId: 'abcDEF12_-x',
      end: 10,
      synced: true,
      lines: [LyricLine(t: 1.5, en: 'hi', ko: '안녕')],
    );
    final back = Song.fromJson(song.toJson());
    expect(back.toJson(), song.toJson());

    final v = VocabItem(word: 'w', gloss: 'g', context: 'c', box: 2, dueAt: 99);
    expect(VocabItem.fromJson(v.toJson()).toJson(), v.toJson());
  });

  test('기본 콘텐츠: 퀴즈 정답 범위와 학습 포인트 형식', () {
    for (final s in stories) {
      expect(s.quiz.answer, inInclusiveRange(0, s.quiz.options.length - 1), reason: s.id);
      for (final sent in s.sentences) {
        // 괄호 짝이 맞지 않으면 plainText 뒤에 [ 나 | 가 남는다.
        expect(plainText(sent.en), isNot(contains('|')), reason: sent.en);
        expect(plainText(sent.en), isNot(contains('[')), reason: sent.en);
      }
    }
    final demo = demoSong();
    for (var i = 1; i < demo.lines.length; i++) {
      expect(demo.lines[i].t, greaterThan(demo.lines[i - 1].t));
    }
  });
}
