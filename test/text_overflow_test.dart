import 'dart:math' as math;

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart'
    show AchievementsView, dailyGoalAchievementCategoryLabels;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_infosecmanage/data/core_features.dart';
import 'package:ukalab_infosecmanage/data/exam_repository.dart';
import 'package:ukalab_infosecmanage/data/progress_store.dart';
import 'package:ukalab_infosecmanage/main.dart';
import 'package:ukalab_infosecmanage/screens/home_screen.dart';
import 'package:ukalab_infosecmanage/screens/learn_screen.dart';
import 'package:ukalab_infosecmanage/screens/mistake_note_screen.dart';
import 'package:ukalab_infosecmanage/screens/mock_exam_screen.dart';
import 'package:ukalab_infosecmanage/screens/pace_run_screen.dart';
import 'package:ukalab_infosecmanage/screens/reading_screen.dart';
import 'package:ukalab_infosecmanage/screens/record_screen.dart';
import 'package:ukalab_infosecmanage/screens/route_planner_screen.dart';
import 'package:ukalab_infosecmanage/screens/settings_screen.dart';
import 'package:ukalab_infosecmanage/screens/terms_screen.dart';
import 'package:ukalab_infosecmanage/widgets/oshi_medal_button.dart';

import 'test_support.dart';

/// 文字切れ・はみ出しの回帰テスト。
///
/// 幅 320dp / 280dp × 文字倍率 1 / 2 / 3 で主要画面を実データ（最長の選択肢・問題文・用語）で組み、
/// 次の2つが出ないことを確かめる。
///  - RenderFlex などの overflow（黄黒の縞が出るはみ出し）
///  - 描画された Text が maxLines / ellipsis で切られて、文言が隠れている
void main() {
  late ExamData data;
  late List<Question> hard; // 実データのうち、文字量の多い問題
  late List<Question> hardA;
  late List<Question> hardB;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // テストの既定フォント（Ahem）は全ての字が 1em 四方で、英数字を実機より広く測ってしまう。
    // 実機と同じ幅で測るため、アプリ同梱のフォントを読み込む（theme の fontFamily と同じ名前）。
    final font = FontLoader(kAppFontFamily)
      ..addFont(rootBundle.load('assets/fonts/BIZUDPGothic-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BIZUDPGothic-Bold.ttf'));
    await font.load();
    data = await loadExamData();
    int weight(Question q) =>
        q.prompt.length +
        q.explanation.length +
        q.choices.fold<int>(0, (a, c) => a + c.length);
    List<Question> top(String subject, int n) {
      final l =
          data.activeQuestions.where((q) => q.subjectId == subject).toList()
            ..sort((a, b) => weight(b).compareTo(weight(a)));
      return l.take(n).toList();
    }

    hardA = top('kamoku_a', 3);
    hardB = top('kamoku_b', 3);
    // 規格名（ISO/IEC 27001 など）・英語の略語を含む問題も混ぜる。
    final withStd = data.activeQuestions
        .where(
          (q) => q.choices.any(
            (c) => c.contains('ISO/IEC') || c.contains('Non-repudiation'),
          ),
        )
        .take(2);
    hard = [...hardA, ...hardB, ...withStd];
  });

  _matrix('アプリ全体（5タブ）', () => data, (h, tester) async {
    await h.pumpApp();
    final nav = find.byType(NavigationDestination);
    for (var i = 0; i < 5; i++) {
      await tester.tap(nav.at(i));
      await h.settle();
      await h.check('shell-tab$i');
    }
  });

  _matrix('ホーム（プレミアム・履歴あり・試験日あり）', premium: true, () => data, (
    h,
    tester,
  ) async {
    await h.seed(hard, wrong: true);
    await h.pump(
      HomeScreen(
        exam: data.exam,
        questions: data.activeQuestions,
        terms: data.terms,
        chapterReadings: data.chapterReadings,
      ),
    );
    await h.container
        .read(examDateProvider.notifier)
        .setDate(DateTime.now().add(const Duration(days: 3)));
    await h.settle();
    await h.check('home-premium');
  });

  _matrix('演習（出題・回答後の解説）', () => data, (h, tester) async {
    await h.pump(
      LearnScreen(questions: hard, terms: data.terms, sessionSize: hard.length),
    );
    await h.check('learn-question');
    // 不正解の選択肢を押して、解説・原因・比較を出す。
    final tiles = tester
        .widgetList<ChoiceTile>(find.byType(ChoiceTile))
        .toList();
    final wrongText = tiles
        .map((t) => t.text)
        .firstWhere(
          (t) => hard.every((x) => x.choices[x.answerIndex] != t),
          orElse: () => tiles.first.text,
        );
    await h.tapVisible(
      find
          .byWidgetPredicate((w) => w is ChoiceTile && w.text == wrongText)
          .first,
    );
    await h.settle();
    expect(find.byType(ExplanationPanel), findsOneWidget);
    await h.check('learn-answered');
  });

  _matrix('演習（ながら学習モード）', () => data, (h, tester) async {
    await h.pump(
      LearnScreen(questions: hard, terms: data.terms, sessionSize: hard.length),
    );
    await h.container.read(handsFreeProvider.notifier).setEnabled(true);
    await h.settle();
    await h.check('learn-handsfree');
  });

  _matrix('模擬試験（導入・出題・結果・カスタム設定）', premium: true, () => data, (
    h,
    tester,
  ) async {
    await h.pump(MockExamScreen(exam: data.exam, questions: hard));
    await h.check('mock-intro');
    await h.tapVisible(find.text('模擬試験を始める'));
    await h.settle();
    await h.check('mock-question');
    for (var i = 0; i < 12; i++) {
      if (find.byType(ChoiceTile).evaluate().isEmpty) break;
      await h.tapVisible(find.byType(ChoiceTile).first);
      await h.settle();
      final next = find.byType(FilledButton);
      await h.tapVisible(next.first);
      await h.settle();
    }
    await h.settle(real: true);
    expect(find.byType(ResultSummary), findsOneWidget);
    await h.check('mock-result');
    await h.pump(CustomMockExamSetupScreen(subjects: data.exam.subjects));
    await h.check('mock-custom-setup');
  });

  _matrix('記録・実績', () => data, (h, tester) async {
    await h.seed(hard, wrong: true);
    await h.pump(
      RecordScreen(exam: data.exam, questions: data.activeQuestions),
    );
    await h.scrollAll('record');
    await h.pump(
      const AchievementsView(
        categoryLabels: dailyGoalAchievementCategoryLabels,
      ),
    );
    await h.check('achievements');
  });

  for (final premium in [false, true]) {
    _matrix('設定（${premium ? 'プレミアム' : '無料'}）', () => data, premium: premium, (
      h,
      tester,
    ) async {
      await h.pump(
        SettingsScreen(
          questions: data.activeQuestions,
          exam: data.exam,
          terms: data.terms,
        ),
      );
      await h.container.read(handsFreeProvider.notifier).setEnabled(true);
      await h.settle(real: true);
      await h.scrollAll('settings');
    });
  }

  _matrix('用語集（一覧・検索・用語カード）', () => data, (h, tester) async {
    Widget terms() => Scaffold(
      appBar: AppBar(title: const Text('用語集')),
      body: TermsScreen(exam: data.exam, terms: data.terms),
    );
    await h.pump(terms());
    await h.scrollAll('terms-list', step: 1200);
    await h.pump(terms()); // 先頭に戻す
    final longest = ([
      ...data.terms,
    ]..sort((a, b) => b.term.length.compareTo(a.term.length))).first;
    await tester.enterText(find.byType(TextField), longest.term);
    await h.settle();
    await h.check('terms-search');
    await h.tapVisible(
      find
          .descendant(
            of: find.byType(ListTile),
            matching: find.text(longest.term),
          )
          .first,
    );
    await h.settle();
    expect(find.byType(TermCard), findsOneWidget);
    await h.check('terms-card');
  });

  _matrix('解説読み物（一覧・本文）', () => data, (h, tester) async {
    await h.pump(
      Scaffold(
        body: ReadingListScreen(
          readings: data.chapterReadings,
          terms: data.terms,
          questions: data.activeQuestions,
          termReferences: data.termReferences,
        ),
      ),
    );
    await h.scrollAll('reading-list');
    await h.tapVisible(find.byType(ListTile).first);
    await h.settle();
    await h.check('reading-body');
  });

  _matrix('間違いノート', () => data, (h, tester) async {
    await h.seed(data.activeQuestions.take(40).toList(), wrong: true);
    await h.pump(
      MistakeNoteScreen(
        exam: data.exam,
        questions: data.activeQuestions,
        terms: data.terms,
        store: InMemoryMistakeNoteStore(),
      ),
    );
    await h.settle(real: true);
    expect(find.byType(MistakeNoteView), findsOneWidget);
    await h.scrollAll('mistake-note');
  });

  _matrix('100問ペース走・最短ルート・チェックリスト・更新ログ・書き出し', () => data, (h, tester) async {
    await h.pump(Scaffold(body: PaceRunScreen(questions: hard)));
    await h.check('pace-intro');
    await h.tapVisible(find.byType(FilledButton));
    await h.settle();
    await h.check('pace-run');
    for (var i = 0; i < hard.length; i++) {
      if (find.byType(ChoiceTile).evaluate().isEmpty) break;
      await h.tapVisible(find.byType(ChoiceTile).first);
      await h.settle();
    }
    expect(find.text('最後まで解き終えました'), findsOneWidget);
    await h.check('pace-result');

    await h.pump(
      RoutePlannerScreen(
        exam: data.exam,
        level: data.exam.levels.first,
        questions: data.activeQuestions,
      ),
    );
    await h.check('route-planner');

    final items = await tester.runAsync(loadChecklist);
    await h.pump(
      ExamDayChecklistView(
        examId: kExamId,
        items: items!,
        venue: ExamVenueKind.venue,
        initialProgress: const ChecklistProgress(),
        onChanged: (_) {},
      ),
    );
    await h.check('checklist');

    await h.pump(
      UpdateLogView(entriesFuture: Future.value(const <UpdateLogEntry>[])),
    );
    await h.check('update-log');
  });

  _matrix('推し（メダル・着せ替え・キャラ選択）', () => data, (h, tester) async {
    await h.seed(hard, wrong: false, streak: 30, mockPassed: true);
    await h.pump(
      Scaffold(
        body: Center(
          child: OshiMedalButton(
            totalQuestions: data.activeQuestions.length,
            shareImage: (_) async {},
          ),
        ),
      ),
    );
    h.container.read(progressProvider); // 保存済みの進捗を読み込ませる
    await h.settle(real: true);
    await h.tapVisible(find.text('メダルを見る・共有'));
    await h.settle();
    await h.check('medal-sheet');
    await h.tapVisible(find.byType(ListTile).at(1));
    await h.settle();
    await h.check('medal-dialog');
    await h.pump(WardrobeScreen(cert: UkalabCert.infoSecurity));
    await h.check('wardrobe');
    await h.pump(const CharacterSelectScreen());
    await h.check('character-select');
  });

  _matrix('ホームから開く画面（AppBar の題名・一覧）', () => data, premium: true, (
    h,
    tester,
  ) async {
    await h.seed(hard, wrong: true);
    await h.pump(
      HomeScreen(
        exam: data.exam,
        questions: data.activeQuestions,
        terms: data.terms,
        chapterReadings: data.chapterReadings,
      ),
    );
    for (final t in ['間違いノート', '用語集', '分野ごとの解説読み物', '最短ルートプランナー', '100問ペース走']) {
      final f = find.text(t).first;
      await h.tapVisible(f);
      await h.settle(real: true);
      expect(find.byType(AppBar), findsOneWidget, reason: t);
      await h.check('home>$t');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await h.settle();
    }
  });

  _matrix('設定のダイアログ（リセット確認・読み込み）', () => data, (h, tester) async {
    await h.pump(
      SettingsScreen(
        questions: data.activeQuestions,
        exam: data.exam,
        terms: data.terms,
      ),
    );
    for (final label in ['学習記録をリセット', '読み込む']) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await h.tapVisible(find.text(label).first);
      await h.settle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: label);
      await h.check('settings-dialog>$label');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await h.settle();
    }
  });

  _matrix('履歴の書き出し', () => data, (h, tester) async {
    final now = DateTime.now();
    await h.pump(
      HistoryExportView(
        records: [
          for (final q in hard) historyRecordFor(q, correct: false, at: now),
        ],
        questions: data.activeQuestions,
      ),
    );
    await h.check('history-export');
  });
}

/// [body] を、幅 × 文字倍率の全組み合わせで（組み合わせごとに画面を作り直して）実行する。
/// RenderFlex の overflow 通知は同じ描画オブジェクトでは1回しか出ないため、組み合わせごとに作り直す。
void _matrix(
  String name,
  ExamData Function() data,
  Future<void> Function(_Harness h, WidgetTester tester) body, {
  bool premium = false,
}) {
  testWidgets(name, (tester) async {
    final all = <String>[];
    for (final c in _combos) {
      if (_onlyCombo.isNotEmpty && '$c' != _onlyCombo) continue;
      final h = _Harness(tester, data(), c, premium: premium);
      final old = FlutterError.onError;
      FlutterError.onError = (d) => h.errors.add(_summarize(d));
      try {
        h.begin();
        try {
          await body(h, tester);
        } catch (e, st) {
          Error.throwWithStackTrace(StateError('[$name @ $c] $e'), st);
        }
        h.flush('end');
      } finally {
        FlutterError.onError = old;
        tester.platformDispatcher.clearAllTestValues();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
      all.addAll(h.findings);
    }
    final external = all.where(_isExternal).toSet();
    final own = all.toSet().difference(external);
    if (external.isNotEmpty) {
      debugPrint(
        '[外部パッケージ起因・このリポジトリでは直せない指摘 ${external.length}件] $name\n'
        '${external.take(6).join('\n')}',
      );
    }
    if (own.isNotEmpty) fail('\n${own.join('\n')}');
  });
}

String _summarize(FlutterErrorDetails d) {
  final s = d.toDiagnosticsNode().toStringDeep();
  final over = RegExp(
    r'overflowed by [\d.]+ pixels on the \w+',
  ).firstMatch(s)?.group(0);
  final loc = RegExp(r'(\w+:file:///\S+)')
      .firstMatch(s)
      ?.group(1)
      ?.replaceAll(
        RegExp(r'file:///(root/\.pub-cache/git/|home/user/work/infosec_clip/)'),
        '',
      );
  final chain = RegExp(
    r'creator: (.+(?:\n\s{4}.+)?)',
  ).firstMatch(s)?.group(1)?.replaceAll(RegExp(r'\s+'), ' ');
  if (over != null) return '$over | $loc | $chain';
  return s.split('\n').take(3).join(' | ');
}

/// ukalab_core / app_common_kit（別リポジトリ）の画面が原因の指摘か。
///
/// このリポジトリのコードでは直せないので、テストは失敗にしない（PR の報告に残課題として列挙）。
/// 判定は次のどちらか。
///  - はみ出しの発生元ウィジェットの場所が、ukalab_core / app_common_kit の `lib/` 内
///  - 「文言が省略されている」のうち、下の [_externalEllipsis] にある外部画面の文言
/// このリポジトリ（lib/）の画面が原因の指摘は、ここに入らず必ずテストが失敗する。
bool _isExternal(String finding) {
  if (RegExp(
    r'(ukalab_core|app_common_kit)-[0-9a-f]{40}/lib/',
  ).hasMatch(finding)) {
    return true;
  }
  if (finding.contains('文言が省略されている')) {
    return _externalEllipsis.any(finding.contains);
  }
  return false;
}

/// 外部パッケージの画面にある、1行で切れている文言。
const _externalEllipsis = [
  // 用語集の一覧（core の GlossaryListView。副題が maxLines: 1 / ellipsis）。実データは用語の headline。
  '[terms-list @',
  '[terms-search @',
  '[terms-card @', // 検索結果の副題（用語カードのシートの背後の一覧）
  '[home>用語集 @',
  // メダルの共有カード（core の OshiMedalShareCard。固定比率のカードで、メダル名が2行までで切れる）。
  '[medal-dialog @',
  // 演習の自分用メモ欄（core の QuestionMemoField）。
  '自分用メモ',
  '間違えた理由や覚え方を書き残せます',
  // core の画面の AppBar の題名。
  '試験当日チェックリスト',
  '学習データの書き出し（CSV）',
  // 書き込みダイアログ（core の DataManagementSection）の入力欄のヒント。
  '{ "version": 1, ... }',
];

class _Combo {
  const _Combo(this.width, this.scale);
  final double width;
  final double scale;
  @override
  String toString() => '${width.toInt()}dp x$scale';
}

/// 原因調査用: `--dart-define=OVERFLOW_COMBO='280dp x3.0'` で1つの組み合わせだけ実行する。
const _onlyCombo = String.fromEnvironment('OVERFLOW_COMBO');

const _combos = [
  _Combo(320, 1),
  _Combo(320, 2),
  _Combo(320, 3),
  _Combo(280, 1),
  _Combo(280, 2),
  _Combo(280, 3),
];

class _Harness {
  _Harness(this.tester, this.data, this.combo, {this.premium = false});

  final WidgetTester tester;
  final ExamData data;
  final _Combo combo;
  final bool premium;
  late ProviderContainer container;
  final findings = <String>[];
  final errors = <String>[];
  var _prefs = <String, Object>{};
  var _containerReady = false;

  void begin() {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(combo.width, 640);
    tester.platformDispatcher.textScaleFactorTestValue = combo.scale;
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  }

  Future<void> _ensureContainer() async {
    if (_containerReady) return;
    _containerReady = true;
    // testAdGate が SharedPreferences を空で初期化するので、その後に保存済みの値を入れる。
    final gate = await tester.runAsync(testAdGate);
    SharedPreferences.setMockInitialValues(_prefs);
    container = ProviderContainer(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(
          CoinService(store: InMemoryCoinStore()),
        ),
        outfitServiceProvider.overrideWithValue(
          OutfitService(store: InMemoryOutfitStore()),
        ),
        entitlementServiceProvider.overrideWithValue(
          FakeEntitlementService(
            initial: premium
                ? const EntitlementState(hasPremium: true, hasNoAds: true)
                : EntitlementState.free,
            availableOffers: const [
              EntitlementOffer(
                id: 'noads',
                productId: 'info_security_noads',
                title: '広告非表示',
                priceString: '¥480',
              ),
              EntitlementOffer(
                id: 'premium',
                productId: 'info_security_premium',
                title: 'プレミアム（広告非表示＋追加機能）',
                priceString: '¥1,500',
              ),
            ],
          ),
        ),
        adGateProvider.overrideWithValue(gate!),
        examStatsServiceProvider.overrideWithValue(FakeExamStatsService()),
        examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
        mockExamHistoryServiceProvider.overrideWithValue(
          MockExamHistoryService(store: MockExamHistoryStore('test')),
        ),
        examDataProvider.overrideWith((ref) async => data),
      ],
    );
    addTearDown(container.dispose);
  }

  /// 解答履歴・進捗を保存済みにして、画面が読み込むようにする（画面を出す前に呼ぶ）。
  Future<void> seed(
    List<Question> qs, {
    required bool wrong,
    int streak = 3,
    bool mockPassed = false,
  }) async {
    final now = DateTime.now();
    final records = [
      for (final q in qs) historyRecordFor(q, correct: !wrong, at: now),
    ];
    _prefs = {
      'ukalab_infosecmanage_history_v1': encodeHistory(records),
      'ukalab_infosecmanage_progress_v1':
          '{${qs.map((q) => '"${q.qid}":${!wrong}').join(',')}}',
      'ukalab_infosecmanage_last_study_day_v1': studyDayKey(now),
      'ukalab_infosecmanage_streak_days_v1': streak,
      'ukalab_infosecmanage_mock_passed_ever_v1': mockPassed,
    };
  }

  Widget _wrap(Widget home) {
    final base = UkalabTheme.light(
      field: UkalabField.it,
      cert: UkalabCert.infoSecurity,
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: true),
          child: child!,
        ),
        locale: const Locale('ja', 'JP'),
        theme: base.copyWith(
          textTheme: base.textTheme.apply(fontFamily: kAppFontFamily),
        ),
        home: home is Scaffold ? home : Scaffold(body: home),
      ),
    );
  }

  Future<void> pump(Widget home) async {
    await _ensureContainer();
    await tester.pumpWidget(_wrap(home));
    await settle(real: true);
  }

  /// アプリ本体（下部タブつき）を起動する。
  Future<void> pumpApp() async {
    await _ensureContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const UkalabInfoSecurityApp(),
      ),
    );
    await settle(real: true);
  }

  /// 画面外にあるものは先にスクロールして見える位置へ出してからタップする。
  Future<void> tapVisible(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 100));
    // 文字を大きくすると選択肢1つが画面より高くなる。中央ではなく左上寄りを押す。
    final topLeft = tester.getTopLeft(f);
    final size = tester.getSize(f);
    await tester.tapAt(
      topLeft +
          Offset(math.min(size.width / 2, 40), math.min(size.height / 2, 30)),
    );
  }

  Future<void> settle({bool real = false}) async {
    if (real) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// ここまでに出たはみ出しと、いま描かれている Text の「文言が省略されている」箇所を集める。
  Future<void> check(String stage) async {
    await tester.pump(const Duration(milliseconds: 50));
    flush(stage);
    for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
      if (p.didExceedMaxLines) {
        final t = p.text.toPlainText();
        findings.add(
          '[$stage @ $combo] 文言が省略されている: ${t.length > 40 ? '${t.substring(0, 40)}…' : t}',
        );
      }
    }
  }

  /// 最初のスクロール領域を端まで少しずつ動かし、遅延生成される行も含めて検査する。
  /// ListView は画面外の行を作らないため、動かさないとはみ出しが見つからない。
  Future<void> scrollAll(
    String stage, {
    double step = 300,
    int maxSteps = 80,
  }) async {
    final scrollables = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.vertical,
    );
    if (scrollables.evaluate().isEmpty) {
      await check(stage);
      return;
    }
    final finder = scrollables.first;
    for (var i = 0; i < maxSteps; i++) {
      await check(stage);
      final position = tester.state<ScrollableState>(finder).position;
      if (position.pixels >= position.maxScrollExtent) break;
      await tester.drag(finder, Offset(0, -step), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void flush(String stage) {
    for (final e in errors.toSet()) {
      findings.add('[$stage @ $combo] overflow: $e');
    }
    errors.clear();
  }
}
