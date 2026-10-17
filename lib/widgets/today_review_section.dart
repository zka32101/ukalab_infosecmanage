import 'package:app_common_kit/app_common_kit.dart' show EntitlementState, entitlementStateProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';

import '../data/history_store.dart';
import '../data/mock_exam_quota.dart';
import '../data/mistake_notes.dart';
import '../data/review_schedule.dart';

/// ホームの「今日の復習」。間違いノートの「これから」の問題を、忘れる頃に見返す予定にして、
/// 期限が来た件数だけを穏やかに知らせる(ukalab_core の [TodayReviewCard]。文言・色は core)。
///
/// 復習の出題画面は新しく作らず、「やってみる」([onStart])は既存の間違いノートを開く。
/// 解き直した結果は演習の解答記録から復習予定へ反映される。
class TodayReviewSection extends ConsumerStatefulWidget {
  const TodayReviewSection({
    super.key,
    required this.onStart,
    this.clock = DateTime.now,
  });

  /// 「やってみる」。既存の間違いノート画面を開き、閉じるまで待つ。
  final Future<void> Function() onStart;
  final DateTime Function() clock;

  @override
  ConsumerState<TodayReviewSection> createState() => _TodayReviewSectionState();
}

/// 無料版の「今日の復習」の1日の件数(方針 D6)。
const _freeReviewPerDay = 10;

class _TodayReviewSectionState extends ConsumerState<TodayReviewSection> {
  /// 無料版の今日の残り回数。読み込み前・プレミアムは null(制限しない)。
  int? _freeRemaining;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  /// 間違いノート(保存済み + 最新の解答履歴)から復習予定を同期する。履歴の読み込み完了を待つ。
  Future<void> _sync() async {
    try {
      await ref.read(historyProvider.notifier).ready;
      if (!mounted) return;
      final stored = await mistakeNoteStore.read();
      if (!mounted) return;
      final notes = mistakeNoteEngine.update(stored, ref.read(historyProvider));
      await ref.read(reviewScheduleProvider.notifier).sync(notes);
      final remaining = (await todayReviewQuota(isPremium: false)).remaining;
      if (mounted) setState(() => _freeRemaining = remaining);
    } catch (_) {
      // 読めなければ件数 0 のまま(静かに「おやすみ」表示)。
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historyProvider, (_, __) => _sync());
    final items = ref.watch(reviewScheduleProvider);
    var due = reviewSchedulerEngine.dueCount(items, widget.clock());
    // 無料版は1日の復習が決まった数まで(プレミアムは無制限)。
    final isPremium = (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium;
    final remaining = isPremium ? null : _freeRemaining;
    if (remaining != null) {
      if (remaining <= 0 && due > 0) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日の復習', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                  '無料版の今日の復習($_freeReviewPerDay問)は終わりました。\n'
                  '続きは明日。プレミアムなら、続けて復習できます(間違いノートは、いつでも開けます)。',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    await widget.onStart();
                    if (mounted) await _sync();
                  },
                  child: const Text('間違いノートを開く'),
                ),
              ],
            ),
          ),
        );
      }
      if (due > remaining) due = remaining;
    }
    return TodayReviewCard(
      dueCount: due,
      onStart: () async {
        await widget.onStart();
        if (mounted) await _sync();
      },
    );
  }
}
