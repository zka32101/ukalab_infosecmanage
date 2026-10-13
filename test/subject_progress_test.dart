import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_infosecmanage/data/subject_progress.dart';
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

void main() {
  test('科目ごとの正答率を計算する', () {
    final questions = [
      _q('q1', 'math_stats'),
      _q('q2', 'math_stats'),
      _q('q3', 'ai_law'),
    ];
    final result = computeSubjectProgress(questions, {
      'q1': true,
      'q2': false,
      'q3': true,
    });

    final mathStats = result.firstWhere((p) => p.subjectId == 'math_stats');
    final aiLaw = result.firstWhere((p) => p.subjectId == 'ai_law');
    expect(mathStats.accuracy, closeTo(0.5, 0.0001));
    expect(aiLaw.accuracy, closeTo(1.0, 0.0001));
  });

  test('1問も解いていない科目は含めない', () {
    final questions = [_q('q1', 'math_stats'), _q('q2', 'ai_law')];
    final result = computeSubjectProgress(questions, {'q1': true});
    expect(result.map((p) => p.subjectId), ['math_stats']);
  });

  test('進捗が空なら空のリストを返す', () {
    final questions = [_q('q1', 'math_stats')];
    expect(computeSubjectProgress(questions, {}), isEmpty);
  });
}
