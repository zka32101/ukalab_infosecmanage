import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/progress_store.dart';
import '../data/subject_progress.dart';

/// 「最短ルートプランナー」画面（型④、決定76・77）。残り日数・弱点・配点から
/// 「今日やる3つ」を出す。
class RoutePlannerScreen extends ConsumerWidget {
  const RoutePlannerScreen({
    super.key,
    required this.exam,
    required this.level,
    required this.questions,
  });

  final ExamConfig exam;
  final LevelConfig level;
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final subjectProgress =
        computeSubjectProgress(questions, progress.answeredQidToCorrect);
    final tasks = const RoutePlanner()
        .plan(exam: exam, level: level, progress: subjectProgress);

    return Scaffold(
      appBar: AppBar(title: const Text('最短ルートプランナー')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RoutePlannerWidget(
          tasks: [
            for (final t in tasks)
              RouteTaskSpec(
                subjectId: t.subjectId,
                subjectName: exam.subject(t.subjectId)?.name ?? t.subjectId,
                belowPassLine: t.belowPassLine,
              ),
          ],
        ),
      ),
    );
  }
}
