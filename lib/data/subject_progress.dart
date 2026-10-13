import 'package:ukalab_core/ukalab_core.dart';

/// 進捗（qidごとの最新正誤）と問題データから、最短ルートプランナー（型④）に
/// 渡す科目別の正答率を計算する。
///
/// 1問も解いていない科目は含めない（RoutePlanner は未着手の科目を
/// 正答率0として扱う）。
List<SubjectProgress> computeSubjectProgress(
  List<Question> questions,
  Map<String, bool> answeredQidToCorrect,
) {
  final bySubject = <String, List<bool>>{};
  for (final q in questions) {
    final correct = answeredQidToCorrect[q.qid];
    if (correct == null) continue;
    bySubject.putIfAbsent(q.subjectId, () => []).add(correct);
  }
  return [
    for (final entry in bySubject.entries)
      SubjectProgress(
        subjectId: entry.key,
        accuracy: entry.value.where((c) => c).length / entry.value.length,
      ),
  ];
}
