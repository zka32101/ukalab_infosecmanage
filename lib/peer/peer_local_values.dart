import 'package:ukalab_core/ukalab_core.dart' show ProgressRecord;

import '../data/progress_store.dart';

/// 「みんなの学習状況」の下準備。端末内の値を取り出すだけの純粋な関数群。
///
/// どこにも送らない。送信側（PeerStatsSink）はこのアプリには存在せず、ここは接続しない。
class PeerLocalValues {
  const PeerLocalValues({
    required this.streakDays,
    required this.totalAnswers,
    required this.uniqueQuestions,
    this.examDate,
  });

  final int streakDays;

  /// 延べ回答数（同じ問題を複数回解いた分も数える）。
  final int totalAnswers;

  /// ユニーク問題数（同じ問題は1つと数える）。
  final int uniqueQuestions;

  /// 試験日（日付だけ。未設定なら null）。
  final DateTime? examDate;

  factory PeerLocalValues.from({
    required ProgressState progress,
    required List<ProgressRecord> records,
    DateTime? examDate,
  }) =>
      PeerLocalValues(
        streakDays: progress.streakDays,
        totalAnswers: totalAnswerCount(records),
        uniqueQuestions: uniqueQuestionCount(records),
        examDate: examDate == null ? null : DateTime(examDate.year, examDate.month, examDate.day),
      );

  /// 延べ回答数。
  static int totalAnswerCount(List<ProgressRecord> records) => records.length;

  /// ユニーク問題数。
  static int uniqueQuestionCount(List<ProgressRecord> records) =>
      records.map((r) => r.qid).toSet().length;
}
