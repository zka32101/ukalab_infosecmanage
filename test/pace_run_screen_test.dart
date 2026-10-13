import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_infosecmanage/screens/pace_run_screen.dart';
import 'package:ukalab_core/ukalab_core.dart';

List<Question> _questions(int count) => [
      for (var i = 0; i < count; i++)
        Question(
          qid: 'q$i',
          examId: 'info_security',
          subjectId: 'ml_overview',
          topicId: 't',
          prompt: '問題$i',
          choices: const ['正解', '不正解'],
          answerIndex: 0,
          explanation: 'e',
          source: QuestionSource.original,
          sourceRef: '自作',
          contentVer: '1',
        ),
    ];

Future<void> _pump(WidgetTester tester, List<Question> questions) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: PaceRunScreen(questions: questions)),
  ));
  await tester.pump();
}

void main() {
  testWidgets('開始前は説明と開始ボタンが出る', (tester) async {
    await _pump(tester, _questions(25));
    expect(find.text('100問ペース走'), findsOneWidget);
    expect(find.text('ペース走を始める'), findsOneWidget);
  });

  testWidgets('開始すると1問目とタイマー・旗ボタンが出る', (tester) async {
    await _pump(tester, _questions(25));
    await tester.tap(find.text('ペース走を始める'));
    await tester.pump();

    // 開始前の説明は消え、問題文（出題順はシャッフルされるため、どの問題かは見ない）が1つ出る。
    // 以前は「問題0 が出ない」ことを確認していたが、1問目に問題0が当たると失敗する（1/25）不安定なテストだった。
    expect(find.text('ペース走を始める'), findsNothing);
    expect(find.textContaining(RegExp(r'^問題\d+$')), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.textContaining('残り'), findsOneWidget);
  });

  testWidgets('旗ボタンをタップすると見直し候補になる', (tester) async {
    await _pump(tester, _questions(25));
    await tester.tap(find.text('ペース走を始める'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.flag), findsOneWidget);

    await tester.tap(find.byIcon(Icons.flag));
    await tester.pump();
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
  });

  testWidgets('選択肢をタップすると次の問題に進み、最後まで進むと結果画面になる', (tester) async {
    await _pump(tester, _questions(2));
    await tester.tap(find.text('ペース走を始める'));
    await tester.pump();

    await tester.tap(find.text('正解').first);
    await tester.pump();
    await tester.tap(find.text('正解').first);
    await tester.pump();

    expect(find.text('最後まで解き終えました'), findsOneWidget);
    expect(find.textContaining('解答数: 2 / 2問'), findsOneWidget);
  });

  testWidgets('1問も解いていない間は「解けないかもしれません」を出さない', (tester) async {
    await _pump(tester, _questions(25));
    await tester.tap(find.text('ペース走を始める'));
    await tester.pump(const Duration(seconds: 3));

    expect(find.textContaining('解けないかもしれません'), findsNothing);
  });

  testWidgets('正誤を数えて、結果画面に正解数を出す', (tester) async {
    await _pump(tester, _questions(2));
    await tester.tap(find.text('ペース走を始める'));
    await tester.pump();

    await tester.tap(find.text('正解').first);
    await tester.pump();
    await tester.tap(find.text('不正解').first);
    await tester.pump();

    expect(find.text('正解数: 1 / 2問'), findsOneWidget);
  });

  testWidgets('問題データが0件でも落ちない', (tester) async {
    await _pump(tester, const []);
    expect(tester.takeException(), isNull);
  });
}
