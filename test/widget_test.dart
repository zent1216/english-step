import 'package:english_step/app_state.dart';
import 'package:english_step/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
  });

  testWidgets('이야기 목록 → 읽기 → 퀴즈 정답이면 완료', (tester) async {
    await tester.pumpWidget(const EnglishStepApp());
    expect(find.text('A Coffee, Please'), findsOneWidget);

    await tester.tap(find.text('A Coffee, Please'));
    await tester.pumpAndSettle();
    expect(find.text('전체 듣기'), findsOneWidget);

    final answer = find.text('가져갔다(포장)');
    await tester.scrollUntilVisible(answer, 300);
    await tester.tap(answer);
    await tester.pumpAndSettle();
    expect(AppState.instance.doneStories, contains('coffee'));
  });

  testWidgets('형광펜 표현을 누르면 뜻 시트 → 단어장에 담기', (tester) async {
    await tester.pumpWidget(const EnglishStepApp());
    await tester.tap(find.text('A Coffee, Please'));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('walks into'));
    await tester.pumpAndSettle();
    expect(find.text('~에 걸어 들어가다'), findsOneWidget);

    await tester.tap(find.text('단어장에 담기'));
    await tester.pumpAndSettle();
    expect(AppState.instance.hasWord('walks into'), isTrue);
    expect(find.text('단어장에 담았어요'), findsOneWidget);
  });

  testWidgets('데모 곡: 빈칸 단계와 가상 시계 재생', (tester) async {
    await tester.pumpWidget(const EnglishStepApp());
    await tester.tap(find.byIcon(Icons.music_note_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Paper Boats'));
    await tester.pumpAndSettle();
    expect(find.text('영상 없이 가사만 진행돼요'), findsOneWidget);

    // 빈칸 단계: 단어를 하나 걸러 지운다 ("I fold a paper..." → "I ____ a _____...")
    await tester.tap(find.text('빈칸'));
    await tester.pumpAndSettle();
    expect(find.textContaining('I ____ a _____ boat'), findsOneWidget);

    // 재생하면 가상 시계가 흐른다
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('탭 이동과 빈 단어장 안내', (tester) async {
    await tester.pumpWidget(const EnglishStepApp());
    await tester.tap(find.byIcon(Icons.style_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 담은 표현이 없어요'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.music_note_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paper Boats'), findsOneWidget);
  });
}
