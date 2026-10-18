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
    test('칸마다 질문·문법 이름·설명이 있고, 예문에 그 칸이 들어 있다', () {
      for (final s in Slot.values) {
        expect(s.ask, isNotEmpty);
        expect(s.grammar, isNotEmpty);
        expect(s.explain.length, greaterThan(40));
        expect(s.samples, isNotEmpty);
        expect(s.samples.any((x) => parseChunks(x).any((c) => c.slot == s)), isTrue, reason: s.name);
      }
    });
    test('-ing · want to · have to 레슨이 있다', () {
      final ids = basicsLessons.map((l) => l.id);
      expect(ids, containsAll(['ing', 'want', 'have']));
    });
    test('문장 만들기', () {
      expect(joinChunks(parseChunks('q:What|h:do|w:you|a:like'), '?'), 'What do you like?');
      expect(parseChunks('a:likes~이유').single.tip, '이유');
    });
  });

  testWidgets('조립 문제: 카드를 놓고 확인하면 채점, 틀리면 이유를 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    final drill = BuildDrill('그는 버스를 타요.', 'w:He|a:takes|o:the bus', wrong: 'a:take~-s가 붙어요');
    var solved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildDrillView(drill: drill, onSolved: () => solved = true),
          ),
        ),
      ),
    );
    // 칸 이름은 처음엔 안 보인다(답을 보고 따라 하지 않게)
    expect(find.text('누가'), findsNothing);
    // 순서 틀리게 놓고 확인
    await tester.tap(find.text('takes'));
    await tester.tap(find.text('He'));
    await tester.tap(find.text('the bus'));
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(find.textContaining('1번째 자리에는 ‘누가’'), findsOneWidget);
    expect(solved, isFalse);
    // 다시 놓기 → 오답 카드 넣고 확인
    await tester.tap(find.text('다시 놓기'));
    await tester.pump();
    for (final t in ['He', 'take', 'the bus']) {
      await tester.tap(find.text(t));
    }
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(find.textContaining('-s가 붙어요'), findsOneWidget);
    // 정답
    await tester.tap(find.text('다시 놓기'));
    await tester.pump();
    for (final t in ['He', 'takes', 'the bus']) {
      await tester.tap(find.text(t));
    }
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(solved, isTrue);
    expect(find.text('He takes the bus.'), findsOneWidget);
    expect(find.text('누가'), findsOneWidget); // 맞히면 색깔 칸으로 구조를 보여준다
  });

  testWidgets('끌어다 사이에 끼우기', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    final drill = BuildDrill('나는 커피를 좋아해요.', 'w:I|a:like|o:coffee');
    var solved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildDrillView(drill: drill, onSolved: () => solved = true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('I'));
    await tester.tap(find.text('coffee'));
    await tester.pump();
    // like를 I와 coffee 사이(coffee 왼쪽)로 끌어다 놓기
    final target = tester.getTopLeft(find.text('coffee')) - const Offset(22, -10);
    final g = await tester.startGesture(tester.getCenter(find.text('like')));
    await g.moveBy(const Offset(5, 5));
    await tester.pump();
    await g.moveTo(target);
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(solved, isTrue);
  });

  testWidgets('놓인 카드 위에 떨어뜨려도 끼워진다(왼쪽 절반 → 앞)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    final drill = BuildDrill('나는 커피를 좋아해요.', 'w:I|a:like|o:coffee');
    var solved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuildDrillView(drill: drill, onSolved: () => solved = true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('I'));
    await tester.tap(find.text('coffee'));
    await tester.pump();
    final g = await tester.startGesture(tester.getCenter(find.text('like')));
    await g.moveBy(const Offset(5, 5));
    await tester.pump();
    await g.moveTo(tester.getTopLeft(find.text('coffee')) + const Offset(2, 5));
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pump();
    expect(solved, isTrue);
  });

  testWidgets('레슨을 끝까지 가면 완료 처리', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const BasicsHomeScreen()));
    expect(find.text('영어 문장 지도'), findsWidgets);
    await tester.scrollUntilVisible(find.text('be동사: ~이다, ~에 있다'), 300);
    await tester.ensureVisible(find.text('be동사: ~이다, ~에 있다'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('be동사: ~이다, ~에 있다'));
    await tester.pumpAndSettle();
    final lesson = basicsLessons.firstWhere((l) => l.id == 'be');
    for (var i = 0; i < lesson.concepts.length; i++) {
      await tester.tap(find.text(i == lesson.concepts.length - 1 ? '튜토리얼 끝 · 카드 문제 시작 ▶' : '다음'));
      await tester.pumpAndSettle();
    }
    for (final d in lesson.drills.cast<BuildDrill>()) {
      for (final c in d.answer) {
        await tester.tap(find.text(c.text));
        await tester.pump();
      }
      await tester.tap(find.text('확인'));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('완료!'), findsOneWidget);
    expect(AppState.instance.doneBasics, contains('be'));
  });

  testWidgets('칸 사전: 누르면 쉬운 설명과 학교 문법 이름이 나온다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppState.instance.load();
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const BasicsHomeScreen()));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('slotRow-m')), 200);
    await tester.ensureVisible(find.byKey(const ValueKey('slotRow-m')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('slotRow-m')));
    await tester.pumpAndSettle();
    expect(find.text('어디서·언제·어떻게?'), findsWidgets);
    expect(find.textContaining('부사 · 부사구(전치사구)', findRichText: true), findsOneWidget);
    expect(find.textContaining('추가 정보 스티커'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('I play soccer in the park.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('I play soccer in the park.'), findsOneWidget);
  });
}
