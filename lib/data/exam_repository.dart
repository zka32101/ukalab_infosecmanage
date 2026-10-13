import 'dart:convert';

import 'package:ukalab_core/ui.dart' show TermReference;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 情報セキュリティマネジメントの試験定義・問題データ・用語データ・解説読み物を assets から読み込む。
class ExamData {
  const ExamData({
    required this.exam,
    required this.questions,
    required this.terms,
    required this.chapterReadings,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final List<Term> terms;

  /// 分野ごとの解説読み物（教科書的なまとめページ）の一覧。
  final List<ChapterReading> chapterReadings;

  List<Question> get activeQuestions => questions.where((q) => !q.disabled).toList();

  Term? termById(String termId) {
    for (final t in terms) {
      if (t.termId == termId) return t;
    }
    return null;
  }

  /// 問題文・解説文中の用語をタップ可能にするための、見出し語ベースの参照一覧。
  List<TermReference> get termReferences => [
        for (final t in terms) TermReference(termId: t.termId, matchText: t.term),
      ];
}

Future<ExamData> loadExamData() async {
  final examText = await rootBundle.loadString('assets/exam/info_security.json');
  final exam = ExamConfig.fromJson(jsonDecode(examText) as Map<String, dynamic>);

  final jsonl = await rootBundle.loadString('assets/questions/info_security.jsonl');
  final parsed = parseQuestionsJsonl(jsonl);

  final termsJsonl = await rootBundle.loadString('assets/terms/info_security.jsonl');
  final parsedTerms = parseTermsJsonl(termsJsonl);

  final readingJsonl = await rootBundle.loadString('assets/experience/reading_info_security.jsonl');
  final parsedReading = parseChapterReadingsJsonl(readingJsonl);

  final issues = [
    ...parsed.issues,
    ...validateQuestions(parsed.questions, exam: exam),
    ...parsedTerms.issues,
    ...validateTerms(parsedTerms.terms, exam: exam, questions: parsed.questions),
    ...parsedReading.issues,
    ...validateChapterReadings(
      parsedReading.items,
      exam: exam,
      termIds: parsedTerms.terms.map((t) => t.termId).toList(),
      questionIds: parsed.questions.map((q) => q.qid).toList(),
    ),
  ];
  if (issues.isNotEmpty) {
    throw StateError('問題・用語データに不備があります: ${issues.first}');
  }
  return ExamData(
    exam: exam,
    questions: parsed.questions,
    terms: parsedTerms.terms,
    chapterReadings: parsedReading.items,
  );
}

final examDataProvider = FutureProvider<ExamData>((ref) => loadExamData());
