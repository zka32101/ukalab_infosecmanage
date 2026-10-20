import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/achievements.dart' show AchievementsView, dailyGoalAchievementCategoryLabels;
import 'package:ukalab_core/ukalab_core.dart';

import '../data/progress_store.dart';
import '../data/subject_progress.dart';

import '../widgets/overflow_safe.dart';

/// 「記録」タブ: 解いた問題数・正答率・連続学習日数・科目別の正答率。
/// 間隔反復・苦手分析・平均点・偏差値は後続（決定30・50）。
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key, this.exam, this.questions = const []});

  final ExamConfig? exam;
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    if (progress.distinctAnswered == 0) {
      return const ScrollableCenter(
        child: EmptyState(
          icon: Icons.insights_outlined,
          message: '学習の記録はこれから。演習を進めると、ここに成績が表示されます。',
        ),
      );
    }
    final theme = Theme.of(context);
    final answered = progress.distinctAnswered;
    final correct = progress.correctCount;
    final rate = (correct * 100 / answered).round();
    // 問題プール全体（フラグ適用後の questions）に対する解答済み・正解済みの割合。
    // プール外の qid（過去に解いて今は除外された問題など）は数えず、100%超えを防ぐ。
    final poolIds = {for (final q in questions) q.qid};
    final poolTotal = poolIds.length;
    final answeredInPool = progress.answeredQidToCorrect.keys.where(poolIds.contains).length;
    final correctInPool =
        progress.answeredQidToCorrect.entries.where((e) => e.value && poolIds.contains(e.key)).length;
    final subjects = computeSubjectProgress(questions, progress.answeredQidToCorrect)
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('学習の記録', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Stat(label: '解いた問題', value: '$answered問')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(label: '正答率', value: '$rate%')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(label: '連続学習', value: '${progress.streakDays}日')),
          ],
        ),
        if (poolTotal > 0) ...[
          const SizedBox(height: 12),
          _Coverage(
            label: '解答済み',
            count: answeredInPool,
            total: poolTotal,
            semanticsKey: 'coverage-answered',
          ),
          const SizedBox(height: 8),
          _Coverage(
            label: '正解済み',
            count: correctInPool,
            total: poolTotal,
            semanticsKey: 'coverage-correct',
          ),
        ],
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('実績'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AchievementsView(categoryLabels: dailyGoalAchievementCategoryLabels),
            ),
          ),
        ),
        Text(
          progress.mockPassedEver ? '模擬試験: 目安の正答率を超えたことがあります' : '模擬試験: まだ目安の正答率を超えていません',
          style: theme.textTheme.bodyMedium,
        ),
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('科目別の正答率（低い順）', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in subjects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(exam?.subject(s.subjectId)?.name ?? s.subjectId)),
                      Text('${(s.accuracy * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: s.accuracy, minHeight: 8),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// 「解答済み N/M問(xx%)」とプログレスバー。total は 1 以上で呼ぶ（0 は呼び出し側で除外）。
class _Coverage extends StatelessWidget {
  const _Coverage({
    required this.label,
    required this.count,
    required this.total,
    required this.semanticsKey,
  });

  final String label;
  final int count;
  final int total;
  final String semanticsKey;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    return Column(
      key: ValueKey<String>(semanticsKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label $count/$total問($percent%)', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: ratio, minHeight: 8),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
