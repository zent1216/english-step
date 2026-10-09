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
      expect(h('M IY1 T'), '미트'); // meet: 긴 모음 뒤 t는 "트"
      expect(h('K AE1 T'), '캣'); // cat: 짧은 모음 뒤 t는 받침
      expect(h('S T AA1 P'), '스탑'); // stop
    });
    test('l 겹침, w·y, sh', () {
      expect(h('P L IY1 Z'), '플리즈'); // please
      expect(h('W AO1 T ER0'), '워터'); // water
      expect(h('M Y UW1 Z IH0 K'), '뮤직'); // music
      expect(h('SH IY1'), '쉬'); // she
    });
    test('끝소리', () {
      expect(h('HH OW1 M'), '홈'); // home: 받침 앞 OW는 "오"
      expect(h('G OW1'), '고우'); // go
      expect(h('W EH1 R'), '웨어'); // where
      expect(h('F AO1 R'), '포'); // for
      expect(h('AO1 R'), '오어'); // or
      expect(h('B OW1 T S'), '보츠'); // boats
      expect(h('L IH1 T AH0 L'), '리틀'); // little
    });
    test('사전에 없는 단어는 철자로', () {
      expect(phonesToHangul(spellToPhones('minsu')), isNotEmpty);
    });
  });

  test('앱에 넣은 사전으로 문장 읽기', () async {
    await HangulPron.instance.load();
    expect(HangulPron.instance.isReady, isTrue);
    expect(HangulPron.instance.sentence('Have a nice day!'), '해브 어 나이스 데이');
    expect(HangulPron.instance.sentence('Can I have an iced latte, please?'), contains('플리즈'));
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
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(actions: const [PronToggle()]),
        body: const PronText('Have a nice day'),
      ),
    ));
    expect(find.text('해브 어 나이스 데이'), findsOneWidget);
    await tester.tap(find.text('한글 발음'));
    await tester.pump();
    expect(find.text('해브 어 나이스 데이'), findsNothing);
    expect(AppState.instance.showPron, isFalse);
    await tester.tap(find.text('한글 발음'));
    await tester.pump();
    expect(find.text('해브 어 나이스 데이'), findsOneWidget);
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
