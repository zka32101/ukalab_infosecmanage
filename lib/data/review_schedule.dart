import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 「今日の復習」(ukalab_core の [ReviewSchedulerEngine])を、このアプリの間違いノートにつなぐ部分。
/// 復習の対象は間違いノートの「これから」の問題だけ(`lib/data/mistake_notes.dart`)。
/// 保存先は端末内(キー `ukalab_infosecmanage_review_schedule`)。保存するのは問題ID・段・日付・分野IDのみ。

final ReviewSchedulerStore reviewSchedulerStore =
    SharedPreferencesReviewSchedulerStore('infosecmanage');

const ReviewSchedulerEngine reviewSchedulerEngine = ReviewSchedulerEngine();

/// 復習予定の状態。ホームの表示と、解答の記録(演習)から使う。
class ReviewScheduleNotifier extends Notifier<List<ReviewItem>> {
  late Future<void> _loaded;

  /// 保存済みの復習予定を読み終えたとき。
  Future<void> get ready => _loaded;

  @override
  List<ReviewItem> build() {
    _loaded = _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final items = await reviewSchedulerStore.read();
      // 読み込み中に反映された分を失わないよう、後から来た状態を優先する。
      if (state.isEmpty) state = items;
    } catch (_) {}
  }

  /// バックアップの読み込み・リセット後に、保存先から読み直す。
  Future<void> reload() async {
    await _loaded;
    state = await reviewSchedulerStore.read();
  }

  /// 間違いノート [notes] から復習予定を同期して保存する(同じ入力なら結果は同じ)。
  Future<void> sync(List<MistakeNoteEntry> notes) async {
    await _loaded;
    state = reviewSchedulerEngine.sync(state, notes);
    await reviewSchedulerStore.write(state);
  }

  /// 1問の結果を反映する。復習予定に無い問題は変わらない。[now] は解答履歴の時刻と同じものを渡す。
  Future<void> applyResult(String qid, {required bool correct, required DateTime now}) async {
    await _loaded;
    if (!state.any((i) => i.qid == qid)) return;
    state = reviewSchedulerEngine.applyResult(state, qid, correct: correct, now: now);
    await reviewSchedulerStore.write(state);
  }
}

final reviewScheduleProvider =
    NotifierProvider<ReviewScheduleNotifier, List<ReviewItem>>(ReviewScheduleNotifier.new);

/// バックアップ・リセットの対象(キー `reviewSchedule`)。読み込み・リセット後は状態も読み直す。
DataPart reviewScheduleDataPart() {
  final base = reviewSchedulerDataPart(reviewSchedulerStore);
  return DataPart(
    id: base.id,
    export: base.export,
    restore: (ref, json) async {
      await base.restore(ref, json);
      await ref.read(reviewScheduleProvider.notifier).reload();
    },
    reset: (ref) async {
      await base.reset(ref);
      await ref.read(reviewScheduleProvider.notifier).reload();
    },
  );
}
