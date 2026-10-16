import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_infosecmanage/screens/learn_screen.dart';

import 'test_support.dart';

/// 選択式の解答直後に、解答した問題の解説・正誤・「N / 全体問目」が出る回帰テスト。
/// （PracticeSession.answer は呼んだ時点で current を次へ進めるため、画面側で保持が必要。）
Question _q(String id) => Question(
      qid: 'fb-$id',
      examId: 'info_security',
      subjectId: 'ml_overview',
      topicId: id,
      prompt: '問題$idの文',
      choices: ['$idの正解', '$idの誤り1', '$idの誤り2', '$idの誤り3'],
      answerIndex: 0,
      explanation: '解説$idの本文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late AdGate adGate;
  late StateSetter rebuildParent;

  Future<void> pumpLearn(WidgetTester tester, List<Question> qs) async {
    adGate = await testAdGate();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        adGateProvider.overrideWithValue(adGate),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            rebuildParent = setState;
            return LearnScreen(questions: qs, terms: const [], sessionSize: qs.length);
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // 出題順はシャッフルされるので、いま出ている問題を画面から判定する。
  String shown() => find.text('問題Aの文').evaluate().isNotEmpty ? 'A' : 'B';

  testWidgets('解答直後(親の再描画後も)は解答した問題の解説・選択肢・「1 / 2問目」のまま', (tester) async {
    await pumpLearn(tester, [_q('A'), _q('B')]);
    final first = shown();
    final other = first == 'A' ? 'B' : 'A';
    expect(find.text('第1問 / 2問'), findsOneWidget);

    await tester.tap(find.text('$firstの誤り1'));
    await tester.pumpAndSettle();
    void check() {
      expect(find.text('解説$firstの本文'), findsOneWidget);
      expect(find.text('解説$otherの本文'), findsNothing);
      expect(find.text('問題$firstの文'), findsOneWidget);
      expect(find.text('問題$otherの文'), findsNothing);
      expect(find.text('$firstの正解'), findsOneWidget);
      expect(find.text('$otherの正解'), findsNothing);
      expect(find.text('第1問 / 2問'), findsOneWidget);
      expect(find.text('第2問 / 2問'), findsNothing);
    }

    check();
    rebuildParent(() {});
    await tester.pumpAndSettle();
    check();
  });

  testWidgets('「次へ」で次の問題(2 / 2問目)に進み、前の解説は消える', (tester) async {
    await pumpLearn(tester, [_q('A'), _q('B')]);
    final first = shown();
    final other = first == 'A' ? 'B' : 'A';
    await tester.tap(find.text('$firstの正解'));
    await tester.pumpAndSettle();
    rebuildParent(() {});
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('次へ'));
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('問題$otherの文'), findsOneWidget);
    expect(find.text('第2問 / 2問'), findsOneWidget);
    expect(find.text('解説$firstの本文'), findsNothing);
    expect(find.text('解説'), findsNothing);
  });

  testWidgets('最後の問題は解説を見てから「次へ」で結果画面へ', (tester) async {
    await pumpLearn(tester, [_q('A'), _q('B')]);
    for (var n = 1; n <= 2; n++) {
      final cur = shown();
      expect(find.text('第$n問 / 2問'), findsOneWidget);
      await tester.tap(find.text('$curの正解'));
      await tester.pumpAndSettle();
      rebuildParent(() {});
      await tester.pumpAndSettle();
      expect(find.text('解説$curの本文'), findsOneWidget);
      expect(find.byType(ResultSummary), findsNothing);
      expect(find.text('第$n問 / 2問'), findsOneWidget);
      await tester.ensureVisible(find.text('次へ'));
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }
    expect(find.byType(ResultSummary), findsOneWidget);
  });
}
