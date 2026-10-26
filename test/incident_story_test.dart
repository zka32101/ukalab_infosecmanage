import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_infosecmanage/data/exam_repository.dart';
import 'package:ukalab_infosecmanage/data/incident_story.dart';
import 'package:ukalab_infosecmanage/screens/incident_story_screen.dart';

late ExamData _data;
late List<IncidentScenario> _scenarios;

Future<void> _pumpList(WidgetTester tester, {required bool premium}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      entitlementStateProvider.overrideWith(
          (ref) => Stream.value(EntitlementState(hasPremium: premium))),
    ],
    child: MaterialApp(
      home: IncidentStoryListScreen(
        terms: _data.terms,
        scenariosFuture: Future.value(_scenarios),
      ),
    ),
  ));
  // pumpAndSettle は使わず、一定回数だけ進める。
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _data = await loadExamData();
    _scenarios = await loadIncidentScenarios();
  });

  group('データ検証', () {
    test('シナリオは8本で、最初の2本だけ無料', () {
      expect(_scenarios.length, 8);
      expect(_scenarios.where((s) => s.isFree).length, 2);
      expect(_scenarios.take(2).every((s) => s.isFree), isTrue);
      expect(_scenarios.skip(2).every((s) => !s.isFree), isTrue);
    });

    test('品質ゲートに通る(AI下書きの印・自作の出典・禁止表現なし・用語の参照先)', () {
      final issues = validateIncidentScenarios(
        _scenarios,
        exam: _data.exam,
        termIds: _data.terms.map((t) => t.termId),
      );
      expect(issues, isEmpty);
      for (final s in _scenarios) {
        expect(s.contentStatus, 'ai-draft');
        expect(s.story.sourceRef, contains('自作'));
        expect(s.story.chapters.length, 5);
      }
    });

    test('禁止表現や AI 下書きの欠落を検出できる', () {
      final bad = parseIncidentScenarios(
        '{"scenarioId":"x","examId":"info_security","title":"過去問で学ぶ","description":"d",'
        '"chapters":[{"chapterId":"a","situation":"s","choices":[{"choiceId":"1","text":"t","isRecommended":true,"feedback":"f"},{"choiceId":"2","text":"u","isRecommended":false,"feedback":"g"}]},'
        '{"chapterId":"b","situation":"s","choices":[{"choiceId":"1","text":"t","isRecommended":true,"feedback":"f"},{"choiceId":"2","text":"u","isRecommended":false,"feedback":"g"}]}],'
        '"source":"original","sourceRef":"自作","contentVer":"1","termIds":["nope"]}',
      );
      final codes = validateIncidentScenarios(
        bad.scenarios,
        exam: _data.exam,
        termIds: _data.terms.map((t) => t.termId),
      ).map((i) => i.code).toSet();
      expect(codes, containsAll(['no-ai-draft', 'forbidden-word', 'unknown-term']));
    });
  });

  group('一覧画面', () {
    testWidgets('無料: 無料シナリオは開け、AI下書きの表示が出る', (tester) async {
      await _pumpList(tester, premium: false);
      expect(find.text(kIncidentStoryDraftNotice), findsOneWidget);
      await tester.tap(find.text(_scenarios[0].story.title));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(IncidentStoryPlayScreen), findsOneWidget);
      expect(find.text(kIncidentStoryDraftNotice), findsOneWidget);
      expect(find.text('第1章 / 全5章'), findsOneWidget);
    });

    testWidgets('無料: プレミアム限定は案内のSnackBarだけで、画面に入れない', (tester) async {
      await _pumpList(tester, premium: false);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(6));
      await tester.tap(find.text(_scenarios[2].story.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(kIncidentPremiumNotice), findsOneWidget);
      expect(find.byType(IncidentStoryPlayScreen), findsNothing);
    });

    testWidgets('プレミアム: 限定シナリオも開け、判断→解説→次の章へ進める', (tester) async {
      await _pumpList(tester, premium: true);
      await tester.tap(find.text(_scenarios[2].story.title));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(IncidentStoryPlayScreen), findsOneWidget);
      expect(find.text(kIncidentPremiumNotice), findsNothing);

      final first = _scenarios[2].story.chapters.first;
      final rec = first.choices.firstWhere((c) => c.isRecommended);
      await tester.tap(find.text(rec.text));
      await tester.pump();
      expect(find.text('よい判断です'), findsOneWidget);
      expect(find.text(rec.feedback), findsOneWidget);
      await tester.tap(find.text('次の章へ'));
      await tester.pump();
      expect(find.text('第2章 / 全5章'), findsOneWidget);
    });
  });
}
