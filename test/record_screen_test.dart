import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_infosecmanage/data/progress_store.dart';
import 'package:ukalab_infosecmanage/screens/record_screen.dart';
import 'package:ukalab_core/ukalab_core.dart';

Question _q(String qid, String subjectId) => Question(
      qid: qid,
      examId: 'info_security',
      subjectId: subjectId,
      topicId: 't',
      prompt: 'p',
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<ProviderContainer> _pump(WidgetTester tester, {required List<Question> questions}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: RecordScreen(questions: questions))),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('1問も解いていなければ、空の案内を出す', (tester) async {
    await _pump(tester, questions: [_q('a', 's1')]);
    expect(find.textContaining('学習の記録はこれから'), findsOneWidget);
  });

  testWidgets('解いた問題数・正答率・科目別の正答率を出す', (tester) async {
    final container = await _pump(tester, questions: [_q('a', 's1'), _q('b', 's1'), _q('c', 's2')]);
    final n = container.read(progressProvider.notifier);
    await n.recordAnswer('a', correct: true);
    await n.recordAnswer('b', correct: false);
    await n.recordAnswer('c', correct: true);
    await tester.pump();

    expect(find.text('3問'), findsOneWidget); // 解いた問題
    expect(find.text('67%'), findsWidgets); // 2/3
    expect(find.text('50%'), findsOneWidget); // s1: 1/2
    expect(find.text('100%'), findsOneWidget); // s2: 1/1
    expect(find.textContaining('学習の記録はこれから'), findsNothing);
  });

  testWidgets('全体に対する解答済み・正解済みの割合を出す', (tester) async {
    final container = await _pump(tester, questions: [_q('a', 's1'), _q('b', 's1'), _q('c', 's2'), _q('d', 's2')]);
    final n = container.read(progressProvider.notifier);
    await n.recordAnswer('a', correct: true);
    await n.recordAnswer('b', correct: false);
    await n.recordAnswer('c', correct: true);
    await tester.pump();

    expect(find.text('解答済み 3/4問(75%)'), findsOneWidget);
    expect(find.text('正解済み 2/4問(50%)'), findsOneWidget);
  });

  testWidgets('問題プールにない解答済みqidは母数・分子に含めない', (tester) async {
    final container = await _pump(tester, questions: [_q('a', 's1'), _q('b', 's1')]);
    final n = container.read(progressProvider.notifier);
    await n.recordAnswer('a', correct: true);
    await n.recordAnswer('gone', correct: true); // フラグで除外された問題など
    await tester.pump();

    expect(find.text('解答済み 1/2問(50%)'), findsOneWidget);
    expect(find.text('正解済み 1/2問(50%)'), findsOneWidget);
  });

  testWidgets('問題プールが空でもゼロ割にならず、割合行を出さない', (tester) async {
    final container = await _pump(tester, questions: const []);
    await container.read(progressProvider.notifier).recordAnswer('a', correct: true);
    await tester.pump();

    expect(find.textContaining('解答済み'), findsNothing);
    expect(find.text('1問'), findsOneWidget);
  });
}
