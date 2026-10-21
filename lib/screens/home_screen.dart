import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_core/daily_goal.dart' show DailyMissionCard;
import 'package:ukalab_core/reminder.dart' show StudyReminderCard;
import 'package:ukalab_core/exam_date.dart';
import '../widgets/oshi_card.dart';
import '../widgets/oshi_growth_section.dart';
import '../widgets/oshi_home_cards.dart';
import '../widgets/today_review_section.dart';
import 'mistake_note_screen.dart';
import 'pace_run_screen.dart';
import 'exam_prep_entry.dart';
import 'premium_practice_cards.dart';
import 'route_planner_screen.dart';

import '../widgets/cert_prop.dart';
import '../widgets/overflow_safe.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDate = ref.watch(examDateProvider);
    final theme = Theme.of(context);
    final adGate = ref.watch(adGateProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('うかラボ 情報セキュリティマネジメント', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '情報セキュリティマネジメント試験 対策（IPA・情報処理推進機構とは無関係の非公式アプリ）',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CertPropAccent(),
            ],
          ),
          const SizedBox(height: 16),
          OshiCard(
            totalQuestions: questions.length,
            exam: exam,
            questions: questions,
            terms: terms,
            examDate: userDate ?? (exam.examDates.isEmpty ? null : exam.examDates.first),
          ),
          const SizedBox(height: 8),
          // 推しの一言(無料)。タップで別の一言。
          OshiMessageCard(
            examDate: userDate ?? (exam.examDates.isEmpty ? null : exam.examDates.first),
          ),
          // ① 今日やること
          HomeSection(
            title: '今日やること',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DailyMissionCard(),
                  const StudyReminderCard(),
                  // 今日の復習(間違いノートから。期限が来た件数だけを静かに知らせる)。「やってみる」は既存の間違いノートへ。
                  TodayReviewSection(
                    onStart: () =>
                        openMistakeNote(context, exam: exam, questions: questions, terms: terms),
                  ),
                  PremiumPracticeCards(exam: exam, questions: questions, terms: terms),
                  const SizedBox(height: 4),
                  HomeMenuTile(
                    icon: Icons.route_outlined,
                    title: '最短ルートプランナー',
                    subtitle: '残り日数・弱点から「今日やる3つ」を出します。',
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
                  const SizedBox(height: 8),
                  HomeMenuTile(
                    icon: Icons.timer_outlined,
                    title: '100問ペース走',
                    subtitle: '本番のペース感覚を短縮版（20問・24分）で体感します。',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => Scaffold(
                          appBar: wrappingAppBar(context, '100問ペース走'),
                          body: PaceRunScreen(questions: questions),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ② 記録
          HomeSection(
            title: '記録',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 週間ふりかえり(無料。今週できたことだけを見せる)。
                  WeeklyRecapSection(exam: exam, questions: questions),
                  // これまでの積み重ねへの推しの反応と、節目の祝福(一度だけ。ホームが最前面のとき)。
                  const OshiGrowthSection(),
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
                ],
              ),
            ),
          ),
          // ③ 試験に向けて
          HomeSection(
            title: '試験に向けて',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CoreFeaturesCard(exam: exam, questions: questions, terms: terms),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: adGate.banner(BannerPlacement.home)),
        ],
      ),
    );
  }
}
