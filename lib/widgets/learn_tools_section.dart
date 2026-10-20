import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/exam_repository.dart';
import 'overflow_safe.dart';
import '../screens/mistake_note_screen.dart';
import '../screens/reading_screen.dart';
import '../screens/terms_screen.dart';

/// 「学ぶ」タブの下部に置く、調べる・見返す入口のまとまり（間違いノート・
/// ブックマーク/メモ・用語集・解説読み物）。以前はホームにあったもの。
class LearnToolsSection extends ConsumerWidget {
  const LearnToolsSection({
    super.key,
    required this.exam,
    required this.questions,
    required this.terms,
    required this.chapterReadings,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final List<Term> terms;
  final List<ChapterReading> chapterReadings;

  /// 一覧から開く問題の詳細。選択肢の記号は演習（A・B・C…）に合わせる。
  Widget _detailBuilder(BuildContext context, Question q) => QuestionDetailScreen(
        question: q,
        choiceLabels: const ['A', 'B', 'C', 'D', 'E', 'F'],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termReferences = ref.watch(examDataProvider).valueOrNull?.termReferences ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('間違いノート'),
            subtitle: const Text('間違えた問題を見返して、解き直せます。'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                openMistakeNote(context, exam: exam, questions: questions, terms: terms),
          ),
        ),
        const SizedBox(height: 16),
        StudyNotesHomeCards(loadQuestions: () async => questions, detailBuilder: _detailBuilder),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('用語集'),
            subtitle: Text('収録${terms.length}語。わからない用語をいつでも調べられます。'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: wrappingAppBar(context, '用語集'),
                  body: TermsScreen(exam: exam, terms: terms),
                ),
              ),
            ),
          ),
        ),
        if (chapterReadings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('分野ごとの解説読み物'),
              subtitle: const Text('科目ごとの解説を読めます。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: wrappingAppBar(context, '分野ごとの解説読み物'),
                    body: ReadingListScreen(
                      readings: chapterReadings,
                      terms: terms,
                      questions: questions,
                      termReferences: termReferences,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
