import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_infosecmanage/data/progress_store.dart';
import 'package:ukalab_infosecmanage/data/review_schedule.dart';
import 'package:ukalab_infosecmanage/screens/mock_exam_screen.dart';
import 'package:ukalab_infosecmanage/widgets/oshi_growth_section.dart';
import 'package:ukalab_infosecmanage/widgets/today_review_section.dart';

Question _q(String qid, String subject, {int answer = 0}) => Question(
      qid: qid,
      examId: 'info_security',
      subjectId: subject,
      topicId: 'topic-$qid',
      prompt: '問題文-$qid',
      choices: const ['a', 'b'],
      answerIndex: answer,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

ProgressRecord _rec(String qid, DateTime at, {bool correct = true}) => ProgressRecord(
      qid: qid,
      subjectId: 'ml_overview',
      correct: correct,
      at: at,
      topicId: 'overfitting',
    );

MistakeNoteEntry _note(String qid, DateTime missedAt) => MistakeNoteEntry(
      qid: qid,
      firstMissedAt: missedAt,
      lastMissedAt: missedAt,
      missCount: 1,
      overcome: false,
      topicId: 'overfitting',
      correctStreak: 0,
      lastAnsweredAt: missedAt,
    );

Future<void> _wait(WidgetTester tester, {int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpPart(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 2400),
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    ),
  ));
  await _wait(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('今日の復習: 復習予定(間違いノートから)', () {
    test('同期した問題が、間違えた翌日に期限になり、正解で段が進む', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reviewScheduleProvider.notifier);
      await notifier.sync([_note('q1', DateTime(2026, 10, 10, 9))]);
      expect(container.read(reviewScheduleProvider).single.stage, 0);
      final day = DateTime(2026, 10, 11, 8);
      expect(reviewSchedulerEngine.dueCount(container.read(reviewScheduleProvider), day), 1);
      await notifier.applyResult('q1', correct: true, now: day);
      final after = container.read(reviewScheduleProvider).single;
      expect(after.stage, 1);
      expect(reviewSchedulerEngine.dueCount([after], day), 0);
      await notifier.reload();
      expect(container.read(reviewScheduleProvider).single.stage, 1);
    });

    test('復習予定に無い問題の結果は何も変えない', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(reviewScheduleProvider.notifier)
          .applyResult('none', correct: false, now: DateTime(2026, 10, 11));
      expect(container.read(reviewScheduleProvider), isEmpty);
    });

    test('保存キーは ukalab_infosecmanage_review_schedule', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(reviewScheduleProvider.notifier)
          .sync([_note('q1', DateTime(2026, 10, 10))]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ukalab_infosecmanage_review_schedule'), contains('q1'));
    });

    testWidgets('期限の来た間違いを数え、「やってみる」で onStart が呼ばれる', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ukalab_infosecmanage_history_v1': encodeHistory([
          _rec('q1', DateTime.now().subtract(const Duration(days: 3)), correct: false),
        ]),
      });
      var started = 0;
      await _pumpPart(tester, TodayReviewSection(onStart: () async => started++));
      expect(tester.widget<TodayReviewCard>(find.byType(TodayReviewCard)).dueCount, 1);
      await tester.tap(find.text('やってみる'));
      await _wait(tester, times: 3);
      expect(started, 1);
    });

    testWidgets('間違いが無ければ件数 0 で、始めるボタンは出ない', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPart(tester, TodayReviewSection(onStart: () async {}));
      expect(tester.widget<TodayReviewCard>(find.byType(TodayReviewCard)).dueCount, 0);
      expect(find.text('やってみる'), findsNothing);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('幅 $width・文字 $scale 倍でオーバーフローしない', (tester) async {
        SharedPreferences.setMockInitialValues({
          'ukalab_infosecmanage_history_v1': encodeHistory([
            _rec('q1', DateTime.now().subtract(const Duration(days: 3)), correct: false),
          ]),
        });
        await _pumpPart(tester, TodayReviewSection(onStart: () async {}),
            size: Size(width, 2400), textScale: scale);
        expect(find.byType(TodayReviewCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('模擬試験の結果分析', () {
    test('分野は科目単位。未回答は不正解として数える', () {
      final picked = [_q('a', 'law'), _q('b', 'law'), _q('c', 'tech', answer: 1)];
      final out = mockExamAnswersFor(picked, {'a': 0, 'b': 1});
      expect([for (final a in out) a.topicId], ['law', 'law', 'tech']);
      expect([for (final a in out) a.correct], [true, false, false]);
    });

    for (final (width, scale) in [(320.0, 2.0), (800.0, 1.0)]) {
      testWidgets('分析カードは幅 $width・文字 $scale 倍でオーバーフローしない', (tester) async {
        final picked = [
          for (var i = 0; i < 6; i++) _q('l$i', 'law'),
          for (var i = 0; i < 4; i++) _q('p$i', 'tech'),
        ];
        final answers = <String, int?>{
          for (var i = 0; i < 6; i++) 'l$i': i < 2 ? 0 : 1,
          for (var i = 0; i < 4; i++) 'p$i': 0,
        };
        await _pumpPart(
          tester,
          MockExamAnalysisCard(
            analysis: const MockExamAnalysisEngine().analyze(mockExamAnswersFor(picked, answers)),
            topicLabel: (id) => id == 'law' ? 'セキュリティ管理' : 'テクノロジ',
          ),
          size: Size(width, 2400),
          textScale: scale,
        );
        expect(find.byType(MockExamAnalysisCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('推しの成長演出', () {
    test('累計: 回答数は履歴件数と解答済み問題数の大きい方、学習日数は学習した日の合計', () {
      final p = oshiGrowthProgressFor(
        progress: const ProgressState(
            answeredQidToCorrect: {'a': true, 'b': false}, lastStudyDay: '2026-10-09'),
        records: [
          _rec('a', DateTime(2026, 10, 1, 9)),
          _rec('b', DateTime(2026, 10, 1, 20)),
          _rec('c', DateTime(2026, 10, 5, 9)),
        ],
      );
      expect(p.totalAnswered, 3);
      expect(p.studyDays, 3);
    });

    testWidgets('吹き出しが出る。節目に届いていなければ祝福は出ない', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpPart(tester, const OshiGrowthSection(), overrides: [
        oshiGrowthServiceProvider
            .overrideWithValue(OshiGrowthService(store: InMemoryOshiGrowthStore())),
      ]);
      expect(find.byType(OshiGrowthBubble), findsOneWidget);
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
    });

    testWidgets('10問に届いていれば祝福を一度だけ出す', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ukalab_infosecmanage_progress_v1': jsonEncode({for (var i = 0; i < 10; i++) 'q$i': true}),
      });
      final service = OshiGrowthService(store: InMemoryOshiGrowthStore());
      await _pumpPart(tester, const OshiGrowthSection(),
          overrides: [oshiGrowthServiceProvider.overrideWithValue(service)]);
      expect(find.byType(OshiGrowthCelebrationCard), findsOneWidget);
      await tester.tap(find.byType(FilledButton).last);
      await _wait(tester, times: 4);
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
      // 作り直しても、同じ節目はもう祝わない。
      await _pumpPart(tester, const OshiGrowthSection(),
          overrides: [oshiGrowthServiceProvider.overrideWithValue(service)]);
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
    });

    testWidgets('ホームが最前面でない(非表示のタブ)ときは祝福を出さない', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ukalab_infosecmanage_progress_v1': jsonEncode({for (var i = 0; i < 10; i++) 'q$i': true}),
      });
      final service = OshiGrowthService(store: InMemoryOshiGrowthStore());
      await _pumpPart(
        tester,
        TickerMode(enabled: false, child: const OshiGrowthSection()),
        overrides: [oshiGrowthServiceProvider.overrideWithValue(service)],
      );
      expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('吹き出しは幅 $width・文字 $scale 倍でオーバーフローしない', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await _pumpPart(
          tester,
          const OshiGrowthSection(),
          size: Size(width, 2400),
          textScale: scale,
          overrides: [
            oshiGrowthServiceProvider
                .overrideWithValue(OshiGrowthService(store: InMemoryOshiGrowthStore())),
          ],
        );
        expect(find.byType(OshiGrowthBubble), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
