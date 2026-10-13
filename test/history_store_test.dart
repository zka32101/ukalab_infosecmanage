import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_infosecmanage/data/history_store.dart';
import 'package:ukalab_core/ukalab_core.dart';

Question _q(String qid, {String topicId = 'ch1'}) => Question(
      qid: qid,
      examId: 'g',
      subjectId: 's1',
      topicId: topicId,
      prompt: 'p',
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: 'r',
      contentVer: '1',
      choices: const ['a', 'b'],
      answerIndex: 0,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('解答を記録し、再起動後も読み込める', () async {
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    await c1.read(historyProvider.notifier).record(_q('q1'), correct: true, ms: 1200);
    await c1.read(historyProvider.notifier).record(_q('q2', topicId: 'ch2'), correct: false);
    expect(c1.read(historyProvider).map((r) => r.qid), ['q1', 'q2']);
    expect(c1.read(historyProvider).first.ms, 1200);
    expect(c1.read(historyProvider).last.topicId, 'ch2');

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(historyProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(historyProvider).map((r) => r.qid), ['q1', 'q2']);
  });

  test('上限を超えたら古いものから捨てる', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(historyProvider.notifier);
    for (var i = 0; i < historyMaxRecords + 3; i++) {
      await n.record(_q('q$i'), correct: true);
    }
    final list = c.read(historyProvider);
    expect(list.length, historyMaxRecords);
    expect(list.first.qid, 'q3');
  });

  test('CSVは日別と分野別の2表で、個人情報の列を持たない', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(historyProvider.notifier).record(
          _q('q1'),
          correct: true,
          at: DateTime(2026, 10, 9, 10),
        );
    final csv = historyCsv(c.read(historyProvider), [_q('q1')]);
    expect(csv, contains('日付,解答数,正答数,正答率(%),学習時間(分)'));
    expect(csv, contains('2026-10-09,1,1,100.0'));
    expect(csv, contains('分野,解答数,正答数,正答率(%)'));
    expect(csv, contains('ch1,1,1,100.0'));
    expect(csv, isNot(contains('q1')));
  });
}
