import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart'
    show
        DataManagementSection,
        ExamPrepStrings,
        FileSaver,
        PremiumBenefitsCard,
        historyCsvFileName,
        shareCsv;
import 'package:ukalab_core/ukalab_core.dart' show ExamConfig, PremiumFeature, Question, Term, historyCsv;

import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromoSection;
import 'package:ukalab_core/daily_goal.dart' show DailyGoalSetting;
import 'package:ukalab_core/reminder.dart' show ReminderSettingsSection;
import 'package:ukalab_core/exam_date.dart';
import '../data/core_features.dart' show isPremiumFor;
import '../data/data_parts.dart';
import '../data/history_store.dart';
import 'exam_prep_entry.dart';
import '../peer/peer_stats_settings_tile.dart';
import 'mistake_note_screen.dart';

/// 設定の購入節に出す、このアプリで使えるプレミアム機能（core の PremiumFeature のうち実装済みのもの）。
const _premiumBenefitFeatures = <PremiumFeature>[
  PremiumFeature.weakDrill,
  PremiumFeature.examEveMode,
  PremiumFeature.tenMinutePlan,
  PremiumFeature.historyExport,
  PremiumFeature.mockExamHistory,
  PremiumFeature.readingReadAloud,
  PremiumFeature.qualificationCharacter,
];

/// 「設定」タブ。課金（決定35）の購入・復元を提供する。広告はnoads/premiumの
/// どちらかを持つと自動的に非表示になる（`AdGate.adsHidden`）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    this.questions = const [],
    this.exam,
    this.terms = const [],
    this.fileSaver,
    this.now,
  });

  /// 学習履歴CSVの保存処理（テスト用の差し替え。省略時は core の既定＝Webはダウンロード、他は共有シート）。
  final FileSaver? fileSaver;

  /// ファイル名の日付に使う現在時刻（テスト用の差し替え）。
  final DateTime Function()? now;

  /// 間違いノートの「解き直す」で演習画面を開くために使う。省略時は間違いノートの入口を出さない。
  final ExamConfig? exam;
  final List<Term> terms;

  /// 履歴CSVの分野集計で、記録に章が無い旧データを補うために使う。
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement =
        ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free;
    final service = ref.watch(entitlementServiceProvider);
    final handsFree = ref.watch(handsFreeProvider);
    final historyExportUnlocked = isPremiumFor(ref, PremiumFeature.historyExport);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          title: Text('このアプリについて'),
          subtitle: Text(
            '「うかラボ 情報セキュリティマネジメント」は、独立行政法人情報処理推進機構（IPA）とは'
            '無関係に開発・運営する非公式の学習アプリです。問題はすべて独自に作成しています。',
          ),
        ),
        const Divider(height: 1),
        ListTile(
          title: const Text('バージョン'),
          // 実際にインストールされた版（pubspec の version）を読む。
          subtitle: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) =>
                Text(snapshot.hasData ? snapshot.data!.version : ''),
          ),
        ),
        const Divider(height: 24),
        SwitchListTile(
          title: const Text('ながら学習モード'),
          subtitle: const Text('大きな選択肢ボタンで、問題を読み上げます。'),
          value: handsFree.enabled,
          onChanged: (v) => ref.read(handsFreeProvider.notifier).setEnabled(v),
        ),
        if (handsFree.enabled)
          SwitchListTile(
            title: const Text('問題を読み上げる'),
            value: handsFree.speakQuestion,
            onChanged: (v) => ref.read(handsFreeProvider.notifier).setSpeakQuestion(v),
          ),
        ExamDateTile(
          date: ref.watch(examDateProvider),
          onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
        ),
        ListTile(
          key: const ValueKey('downloadHistoryCsv'),
          title: const Text('学習履歴をダウンロード（CSV）'),
          leading: historyExportUnlocked ? null : const Icon(Icons.lock_outline),
          subtitle: Text(historyExportUnlocked
              ? '日ごと・分野ごとの解答数と正答率。個人情報は含みません。'
              : '${ExamPrepStrings.of(context).premiumNote}（下の「購入」から）'),
          onTap: () => historyExportUnlocked
              ? _downloadHistory(context, ref)
              : _showHistoryLocked(context),
        ),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('購入', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        if (!entitlement.hasPremium) ...const [
          PremiumBenefitsCard(
            // このアプリで実際に使える機能だけを並べる（カスタム模擬試験は未提供）。
            features: _premiumBenefitFeatures,
            showFreeNote: false,
          ),
          Padding(
            key: ValueKey('premiumBenefitsNote'),
            padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              '問題と解説は無料で使えます。模擬試験と今日の復習は、無料では回数に上限があり、'
              'プレミアムでは無制限です。広告は、広告非表示またはプレミアムで表示されなくなります。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
        if (entitlement.adsHidden)
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(entitlement.hasPremium ? 'プレミアムを購入済みです' : '広告非表示を購入済みです'),
          )
        else
          FutureBuilder<List<EntitlementOffer>>(
            future: service.offers(),
            builder: (context, snapshot) {
              final offers = snapshot.data ?? const [];
              if (offers.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  for (final offer in offers)
                    ListTile(
                      title: Text(offer.title),
                      trailing: FilledButton(
                        onPressed: () => _purchase(context, ref, offer),
                        child: Text(offer.priceString),
                      ),
                    ),
                ],
              );
            },
          ),
        TextButton(
          onPressed: () => _restore(context, ref),
          child: const Text('購入を復元'),
        ),
        const Divider(height: 24),
        if (kPeerStatsSettingsVisible) ...const [PeerStatsSettingsTile(), Divider(height: 24)],
        const DailyGoalSetting(),
        const Divider(height: 24),
        const ReminderSettingsSection(),
        const Divider(height: 24),
        DataManagementSection(
          parts: infoSecurityDataParts,
          description: '学習進捗・解答履歴・自分用メモは、試験日・ブックマークを除いて、'
              '書き出し・読み込み・リセットができます。',
        ),
        CoreFeatureSettingsTiles(questions: questions),
        if (exam != null)
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('間違いノート'),
            subtitle: const Text('間違えた問題を見返して、解き直せます。'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openMistakeNote(context,
                exam: exam!, questions: questions, terms: terms),
          ),
        // 掲載リストが空なら何も表示しない。うかラボは大人向けなので保護者ゲートは不要。
        const UkalabCrossPromoSection(currentAppId: 'com.yourwish.ukalab.infosecmanage'),
      ],
    );
  }

  /// 無料では保存せず、プレミアムの案内だけを出す（購入欄はこの画面の下にある）。
  void _showHistoryLocked(BuildContext context) {
    final note = ExamPrepStrings.of(context).premiumNote;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$note。このページ下の「購入」からプレミアムを選べます。')),
    );
  }

  Future<void> _downloadHistory(BuildContext context, WidgetRef ref) async {
    final records = ref.read(historyProvider);
    final strings = ExamPrepStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (records.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('まだ学習履歴がありません。')));
      return;
    }
    String message;
    try {
      final saved = await shareCsv(
        csv: historyCsv(records, questions),
        fileName: historyCsvFileName((now ?? DateTime.now)()),
        saver: fileSaver,
      );
      message = saved ? strings.exportSaved : '';
    } catch (_) {
      message = strings.exportSaveFailed;
    }
    if (message.isEmpty) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _purchase(BuildContext context, WidgetRef ref, EntitlementOffer offer) async {
    final outcome = await ref.read(entitlementServiceProvider).purchaseOffer(offer.id);
    if (!context.mounted) return;
    final message = switch (outcome) {
      PurchaseOutcome.success => '購入しました。',
      PurchaseOutcome.cancelled => '購入をキャンセルしました。',
      PurchaseOutcome.blockedByGate => '購入できませんでした。',
      PurchaseOutcome.failed => '購入に失敗しました。',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final state = await ref.read(entitlementServiceProvider).restore();
    if (!context.mounted) return;
    final message = state.adsHidden ? '購入を復元しました。' : '復元できる購入がありませんでした。';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
