import 'package:english_step/app_state.dart';
import 'package:english_step/basics/basics_content.dart';
import 'package:english_step/screens/basics_screens.dart';
import 'package:english_step/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('기초 내용 형식', () {
    test('레슨 id가 겹치지 않고, 모든 레슨에 설명과 문제가 있다', () {
      final ids = basicsLessons.map((l) => l.id).toSet();
      expect(ids.length, basicsLessons.length);
      for (final l in basicsLessons) {
        expect(l.concepts, isNotEmpty, reason: l.id);
        expect(l.drills, isNotEmpty, reason: l.id);
      }
    });
    test('조립 문제: 오답 조각에는 이유가 있고, 정답 조각과 글자가 같지 않다', () {
      for (final l in basicsLessons) {
        for (final d in l.drills.whereType<BuildDrill>()) {
          expect(d.answer.every((c) => c.tip == null), isTrue, reason: d.ko);
          for (final w in d.wrong) {
            expect(w.tip, isNotNull, reason: '${d.ko} ${w.text}');
            expect(d.answer.any((a) => a.text == w.text), isFalse, reason: '${d.ko} ${w.text}');
          }
        }
      }
    });
    test('고르기 문제: 정답이 보기에 있다', () {
      for (final l in basicsLessons) {
        for (final d in l.drills.whereType<PickDrill>()) {
          expect(d.options, contains(d.answer));
        }
      }
    });
    test('문장 만들기', () {
      expect(joinChunks(parseChunks('q:What|h:do|w:you|a:like'), '?'), 'What do you like?');
      expect(parseChunks('a:likes~이유').single.tip, '이유');
    });
  });

  testWidgets('조립 문제: 순서대로 누르면 완성, 오답은 이유를 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    final drill = BuildDrill('그는 버스를 타요.', 'w:He|a:takes|o:the bus', wrong: 'a:take~-s가 붙어요');
    var solved = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: BuildDrillView(drill: drill, onSolved: () => solved = true))),
    ));
    await tester.tap(find.widgetWithText(ActionChip, 'takes'));
    await tester.pump();
    expect(find.textContaining('지금은 ‘누가’ 자리'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'He'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'take'));
    await tester.pump();
    expect(find.text('-s가 붙어요'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'takes'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionChip, 'the bus'));
    await tester.pump();
    expect(solved, isTrue);
    expect(find.text('맞았어요!'), findsOneWidget);
    expect(find.text('He takes the bus.'), findsOneWidget);
  });

  testWidgets('레슨을 끝까지 가면 완료 처리', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const BasicsHomeScreen()));
    expect(find.text('영어 문장 지도'), findsWidgets);
    await tester.tap(find.text('be동사: ~이다, ~에 있다'));
    await tester.pumpAndSettle();
    final lesson = basicsLessons.firstWhere((l) => l.id == 'be');
    // 설명 카드 넘기기
    for (var i = 0; i < lesson.concepts.length; i++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    // 조립 문제 풀기
    for (final d in lesson.drills.cast<BuildDrill>()) {
      for (final c in d.answer) {
        await tester.tap(find.widgetWithText(ActionChip, c.text));
        await tester.pump();
      }
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('완료!'), findsOneWidget);
    expect(AppState.instance.doneBasics, contains('be'));
  });
}
