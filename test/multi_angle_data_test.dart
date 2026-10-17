import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_infosecmanage/data/exam_repository.dart';
import 'package:ukalab_infosecmanage/data/feature_flags.dart';

// 出荷データの新形式問題（info_security_multi_angle.jsonl）の整合と、フラグ OFF での非表示を確認する。

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExamData data;
  late List<Question> added;

  setUpAll(() async {
    data = await loadExamData();
    added = data.questions.where((q) => q.qid.startsWith('info_security-ma-')).toList();
  });

  test('新形式問題は 72 問（24 概念 x ○×・空欄補充・説明から用語）で、qid は既存と重複しない', () {
    expect(added.length, 72);
    final ids = data.questions.map((q) => q.qid).toList();
    expect(ids.toSet().length, ids.length);
    expect(added.where((q) => q.type == QuestionType.trueFalse).length, 24);
    expect(added.where((q) => q.type == QuestionType.cloze).length, 24);
    expect(added.where((q) => q.type == QuestionType.reverseLookup).length, 24);
    expect(data.questions.length, 1042 + 72);
  });

  test('全問 ai-draft・original・conceptId が実在する用語を指し、観点が形式に対応する', () {
    final termIds = data.terms.map((t) => t.termId).toSet();
    for (final q in added) {
      expect(q.source, QuestionSource.original, reason: q.qid);
      expect(q.tags, contains('ai-draft'), reason: q.qid);
      expect(termIds, contains(q.conceptId), reason: q.qid);
      expect(q.angle, isNotNull, reason: q.qid);
      expect(isNewQuestionType(q), isTrue, reason: q.qid);
    }
    final byConcept = <String, Set<QuestionAngle>>{};
    for (final q in added) {
      byConcept.putIfAbsent(q.conceptId!, () => {}).add(q.angle!);
    }
    expect(byConcept.length, 24);
    for (final e in byConcept.entries) {
      expect(e.value, {QuestionAngle.trueFalse, QuestionAngle.cloze, QuestionAngle.reverse}, reason: e.key);
    }
  });

  test('表記: 断定的な合格保証や「公式」を含まない', () {
    for (final q in added) {
      final text = [q.prompt, q.explanation, q.clue ?? '', q.sourceRef].join('\n');
      expect(text.contains('公式'), isFalse, reason: q.qid);
      expect(text.contains('必ず合格'), isFalse, reason: q.qid);
      expect(text.contains('合格保証'), isFalse, reason: q.qid);
    }
  });

  test('フラグ OFF（既定）では新形式は出題プールに出ず、選択式は 1042 問のまま', () {
    expect(kNewQuestionTypesEnabled, isFalse);
    expect(data.activeQuestions.length, 1042);
    expect(data.activeQuestions.any(isNewQuestionType), isFalse);
  });
}
