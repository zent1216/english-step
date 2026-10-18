import 'package:english_step/app_state.dart';
import 'package:english_step/hangul_pron.dart';
import 'package:english_step/theme.dart';
import 'package:english_step/widgets/pron_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('발음기호 → 한글', () {
    String h(String p) => phonesToHangul(p.split(' '));
    test('기본', () {
      expect(h('HH AE1 V'), '해브'); // have
      expect(h('N AY1 S'), '나이스'); // nice
      expect(h('D EY1'), '데이'); // day
      expect(h('M IY1 T'), '밋'); // meet: 미국식은 끝 t를 삼켜서 받침
      expect(h('K AE1 T'), '캣'); // cat: 짧은 모음 뒤 t는 받침
      expect(h('S T AA1 P'), '스탑'); // stop
    });
    test('l 겹침, w·y, sh', () {
      expect(h('P L IY1 Z'), '플리즈'); // please
      expect(h('W AO1 T ER0'), '워러'); // water: 미국식 굴리는 t
      expect(h('M Y UW1 Z IH0 K'), '뮤직'); // music
      expect(h('SH IY1'), '쉬'); // she
    });
    test('끝소리', () {
      expect(h('HH OW1 M'), '홈'); // home: 받침 앞 OW는 "오"
      expect(h('G OW1'), '고우'); // go
      expect(h('W EH1 R'), '웨어'); // where
      expect(h('F AO1 R'), '포'); // for
      expect(h('AO1 R'), '오어'); // or
      expect(h('W AO1 K'), '웍'); // walk
      expect(h('JH AA1 B'), '잡'); // job
      expect(h('AW1 T'), '아웃'); // out
      expect(h('TH R IY1'), '쓰리'); // three
      expect(h('B OW1 T S'), '보츠'); // boats
      expect(h('L IH1 T AH0 L'), '리를'); // little
    });
    test('미국식 소리 변화', () {
      expect(h('N AY1 T'), '나잇'); // night
      expect(h('L AY1 K'), '라익'); // like
      expect(h('EH1 V ER0 IY0'), '에버리'); // every
      expect(h('R IH0 P L AY1 D'), '리플라이드'); // replied
      expect(h('S EH1 V AH0 N'), '세븐'); // seven
      expect(h('S T EY1 SH AH0 N'), '스테이션'); // station
      expect(h('B EH1 T ER0'), '베러'); // better
      expect(h('S IH1 T IY0'), '시리'); // city
      expect(h('K AH0 M P Y UW1 T ER0'), '컴퓨러'); // computer
      expect(h('T W EH1 N T IY0'), '퉤니'); // twenty: nt의 t가 빠짐
      expect(h('IH1 N T UW0'), '인투'); // into: 우 앞은 그대로
      expect(h('AH0 T AE1 K'), '어택'); // attack: 강한 모음 앞 t는 그대로
    });
    test('사전에 없는 단어는 철자로', () {
      expect(phonesToHangul(spellToPhones('minsu')), isNotEmpty);
    });
  });

  test('앱에 넣은 사전으로 문장 읽기', () async {
    await HangulPron.instance.load();
    expect(HangulPron.instance.isReady, isTrue);
    expect(HangulPron.instance.sentence('Have a nice day!'), '해버 나이스 데이');
    expect(HangulPron.instance.sentence('Can I have an iced latte, please?'), '캐나이 해번 아이스트 라테 플리즈');
    expect(HangulPron.instance.sentence('the apple'), '디 애플');
    expect(HangulPron.instance.word('an'), '앤'); // 단어 하나만 있으면 원래 소리
    expect(HangulPron.instance.sentence('What time is it?'), '왓 타이미짓');
    expect(HangulPron.instance.sentence('What is it?'), '와리짓');
    expect(HangulPron.instance.sentence('Get up!'), '게럽');
    expect(HangulPron.instance.sentence('Yes, I am.'), '예스 아이 앰'); // 쉼표에서는 끊는다
    expect(HangulPron.instance.sentence('I want to go'), '아이 완트 터 고우');
    expect(HangulPron.instance.sentence('Get up early.'), '게럽 얼리'); // 내용어(early)는 붙이지 않음
    expect(HangulPron.instance.sentence("He doesn't eat."), '히 더즌트 잇'); // 겹자음 끝은 붙이지 않음
    expect(HangulPron.instance.word('to'), '투');
  });

  test('미국식 vs 영국식 비교', () async {
    await HangulPron.instance.load();
    final h = HangulPron.instance;
    final water = h.compare('water')!;
    expect((water.us, water.uk), ('워러', '워터'));
    expect(water.notes.any((n) => n.startsWith('t 소리')), isTrue);
    expect(h.compare('hot')!.uk, '홋');
    expect(h.compare('go')!.uk, '거우');
    expect(h.compare('new')!.uk, '뉴');
    expect(h.compare("can't")!.uk, '칸트');
    expect(h.compare('schedule')!.uk, '셰줄');
    expect(h.compare('nice')!.same, isTrue);
    expect(h.compare('car')!.notes.single, startsWith('r 소리'));
  });

  testWidgets('"한글 발음" 체크로 보이기/숨기기', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    HangulPron.instance.setDictionary({
      'have': ['HH', 'AE1', 'V'],
      'a': ['AH0'],
      'nice': ['N', 'AY1', 'S'],
      'day': ['D', 'EY1'],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          appBar: AppBar(actions: const [PronToggle()]),
          body: const PronText('Have a nice day'),
        ),
      ),
    );
    expect(find.text('해버 나이스 데이'), findsOneWidget);
    await tester.tap(find.text('한글 발음'));
    await tester.pump();
    expect(find.text('해버 나이스 데이'), findsNothing);
    expect(AppState.instance.showPron, isFalse);
    await tester.tap(find.text('한글 발음'));
    await tester.pump();
    expect(find.text('해버 나이스 데이'), findsOneWidget);
  });

  test('시끄러운 곳 모드 설정은 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    expect(AppState.instance.noisyMode, isFalse);
    AppState.instance.setNoisyMode(true);
    await AppState.instance.load();
    expect(AppState.instance.noisyMode, isTrue);
  });
}
