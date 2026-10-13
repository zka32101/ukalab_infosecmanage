import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_core/daily_goal.dart' show DailyMissionCard;
import 'package:ukalab_core/reminder.dart' show StudyReminderCard;
import 'package:ukalab_core/exam_date.dart';
import '../data/exam_repository.dart';
import '../widgets/oshi_card.dart';
import '../widgets/oshi_home_cards.dart';
import 'mistake_note_screen.dart';
import 'pace_run_screen.dart';
import 'exam_prep_entry.dart';
import 'premium_practice_cards.dart';
import 'reading_screen.dart';
import 'route_planner_screen.dart';
import 'terms_screen.dart';

/// 「ホーム」タブ。推し・学習コインを表示（決定67〜77）。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
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
    final userDate = ref.watch(examDateProvider);
    final theme = Theme.of(context);
    final adGate = ref.watch(adGateProvider);
    final termReferences = ref.watch(examDataProvider).valueOrNull?.termReferences ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('うかラボ 情報セキュリティマネジメント', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '情報セキュリティマネジメント試験 対策（IPA・情報処理推進機構とは無関係の非公式アプリ）',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OshiCard(
            totalQuestions: questions.length,
            examDate: userDate ?? (exam.examDates.isEmpty ? null : exam.examDates.first),
          ),
          const SizedBox(height: 8),
          // 推しの一言(無料)。タップで別の一言。
          OshiMessageCard(
            examDate: userDate ?? (exam.examDates.isEmpty ? null : exam.examDates.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('収録問題数', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text('${questions.length}問', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    '「学ぶ」タブで分野別に演習、「模擬」タブで本番形式の採点ができます。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DailyMissionCard(),
          const StudyReminderCard(),
          const SizedBox(height: 16),
          // 週間ふりかえり(無料。今週できたことだけを見せる)。
          WeeklyRecapSection(exam: exam, questions: questions),
          const SizedBox(height: 16),
          PremiumPracticeCards(exam: exam, questions: questions, terms: terms),
          const SizedBox(height: 16),
          CoreFeaturesCard(exam: exam, questions: questions, terms: terms),
          const SizedBox(height: 16),
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
                    appBar: AppBar(title: const Text('用語集')),
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
                subtitle: const Text('ビジネス・テクノロジ・セキュリティ・倫理の3分野を、体系的に読めます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('分野ごとの解説読み物')),
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
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('最短ルートプランナー'),
              subtitle: const Text('残り日数・弱点から「今日やる3つ」を出します。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => RoutePlannerScreen(
                    exam: exam,
                    level: exam.levels.first,
                    questions: questions,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('100問ペース走'),
              subtitle: const Text('本番のペース感覚を短縮版（20問・24分）で体感します。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('100問ペース走')),
                    body: PaceRunScreen(questions: questions),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: adGate.banner(BannerPlacement.home)),
        ],
      ),
    );
  }
}
