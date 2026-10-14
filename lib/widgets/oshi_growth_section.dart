import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/progress_store.dart';

/// 祝い済みの節目の保存先(端末内。キー `ukalab_oshi_growth_infosecmanage`)。テストでは差し替えられる。
final oshiGrowthServiceProvider = Provider<OshiGrowthService>(
  (ref) => OshiGrowthService(store: SharedPreferencesOshiGrowthStore('infosecmanage')),
);

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 推しの成長演出に渡す累計(個人情報・問題IDは入れない)。
///
/// - 累計の回答数: 解答履歴の件数と、解答済みの問題数(重複なし)の大きい方。
///   履歴には保存件数の上限があるため、長く使うと履歴の件数が頭打ちになるが、累計は減らさない。
/// - 学習日数: 解答履歴と連続学習の最終学習日に残っている「学習した日」の合計(連続ではない)。
OshiGrowthProgress oshiGrowthProgressFor({
  required ProgressState progress,
  required List<ProgressRecord> records,
}) {
  final days = <DateTime>{for (final r in records) _day(r.at)};
  final last = progress.lastStudyDay == null ? null : DateTime.tryParse(progress.lastStudyDay!);
  if (last != null) days.add(_day(last));
  return OshiGrowthProgress(
    totalAnswered: math.max(records.length, progress.distinctAnswered),
    studyDays: days.length,
  );
}

/// ホーム(記録まわり)に置く、推しの成長の節目の見張り役。吹き出し(OshiGrowthBubble)はホームに出さない
/// (常時表示は「推しの一言」だけ)。ホームが最前面のときに、新しく迎えた節目があれば一度だけ祝福ダイアログを出す
/// (複数まとめて迎えても1回)。他のタブ・別画面が前にあるときは出さず、ホームに戻ったときに出す。
class OshiGrowthSection extends ConsumerStatefulWidget {
  const OshiGrowthSection({super.key});

  @override
  ConsumerState<OshiGrowthSection> createState() => _OshiGrowthSectionState();
}

class _OshiGrowthSectionState extends ConsumerState<OshiGrowthSection> {
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // タブが切り替わって最前面になったときにも判定する(TickerMode は非表示のタブで無効)。
    TickerMode.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
  }

  bool get _foreground {
    if (!mounted) return false;
    return TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
  }

  Future<void> _celebrate() async {
    if (_checking || !_foreground) return;
    _checking = true;
    try {
      // 履歴の読み込み完了を待つ(読み込み前の少ない累計で判定しない)。
      await ref.read(historyProvider.notifier).ready;
      if (!_foreground) return;
      final service = ref.read(oshiGrowthServiceProvider);
      await service.load();
      if (!_foreground) return;
      final milestone = await service.checkHeadline(oshiGrowthProgressFor(
        progress: ref.read(progressProvider),
        records: ref.read(historyProvider),
      ));
      if (milestone == null || !mounted) return;
      await showOshiGrowthDialog(context, milestone: milestone);
    } catch (_) {
      // 保存に失敗したときは記録されず、次回また祝える。
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 表示はしないが、解答の進み具合の変化を購読して節目の判定を続ける(祝福の発火経路)。
    ref.watch(progressProvider);
    ref.watch(historyProvider);
    return const SizedBox.shrink();
  }
}
