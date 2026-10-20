import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ukalab_core/ui.dart' show FileSaver;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart' show ProgressRecord, encodeHistory;
import 'package:ukalab_infosecmanage/data/history_store.dart' show historyProvider;
import 'package:ukalab_infosecmanage/screens/settings_screen.dart';

import 'test_support.dart';

const _noAdsOffer = EntitlementOffer(
  id: 'noads',
  productId: 'info_security_noads',
  title: '広告非表示',
  priceString: '¥480',
);
const _premiumOffer = EntitlementOffer(
  id: 'premium',
  productId: 'info_security_premium',
  title: 'プレミアム（広告非表示＋追加機能）',
  priceString: '¥1,500',
);

FakeEntitlementService _service() => FakeEntitlementService(
      availableOffers: const [_noAdsOffer, _premiumOffer],
      grantOnPurchase: const {
        'info_security_noads': EntitlementState(hasNoAds: true),
        'info_security_premium': EntitlementState(hasPremium: true),
      },
    );

Widget _app(
  FakeEntitlementService service, {
  FileSaver? saver,
  DateTime Function()? now,
}) =>
    ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(service),
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
      ],
      child: MaterialApp(
        home: Scaffold(body: SettingsScreen(fileSaver: saver, now: now)),
      ),
    );

/// 設定は項目が多く、ListView は画面外を描画しない。縦に長い画面で全項目を描画してから組む。
Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
}

void main() {
  testWidgets('バージョンは固定文字でなく、実際の版を表示する', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'com.example.test',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
    await _pump(tester, _app(_service()));
    await tester.pumpAndSettle();

    expect(find.text('9.8.7'), findsOneWidget);
    expect(find.text('0.1.0'), findsNothing);
  });

  testWidgets('無料の間は購入ボタンが出る', (tester) async {
    await _pump(tester, _app(_service()));
    await tester.pumpAndSettle();

    expect(find.text('広告非表示'), findsOneWidget);
    expect(find.text('¥480'), findsOneWidget);
    expect(find.text('プレミアム（広告非表示＋追加機能）'), findsOneWidget);
  });

  testWidgets('購入すると購入済み表示になり、ボタンが消える', (tester) async {
    final service = _service();
    await _pump(tester, _app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥480'));
    await tester.pumpAndSettle();

    expect(find.text('広告非表示を購入済みです'), findsOneWidget);
    expect(find.text('広告非表示'), findsNothing);
    expect(service.state.hasNoAds, isTrue);
  });

  testWidgets('復元できる購入がなければその旨を表示する', (tester) async {
    await _pump(tester, _app(_service()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();

    expect(find.text('復元できる購入がありませんでした。'), findsOneWidget);
  });

  testWidgets('復元できる購入があれば購入済み表示になる', (tester) async {
    final service = _service()..restorable = const EntitlementState(hasPremium: true);
    await _pump(tester, _app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();

    expect(find.text('購入を復元しました。'), findsOneWidget);
    expect(find.text('プレミアムを購入済みです'), findsOneWidget);
  });

  testWidgets('設定画面の相互紹介は、掲載リストが空（Firebase無し）なら何も出ず例外にもならない', (tester) async {
    await _pump(tester, _app(_service()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('他のアプリもチェック！'), findsNothing);
  });

  group('プレミアムの紹介カード', () {
    testWidgets('無料の間は、このアプリで使える機能だけが並ぶ', (tester) async {
      await _pump(tester, _app(_service()));
      await tester.pumpAndSettle();

      expect(find.text('プレミアムでできること'), findsOneWidget);
      for (final name in [
        'weakDrill',
        'examEveMode',
        'tenMinutePlan',
        'historyExport',
        'mockExamHistory',
        'readingReadAloud',
      ]) {
        expect(find.byKey(ValueKey('premiumBenefit_$name')), findsOneWidget, reason: name);
      }
      // 未提供の機能は載せない。core 既定の「無料の範囲」の一文も使わない。
      expect(find.byKey(const ValueKey('premiumBenefit_customMockExam')), findsNothing);
      expect(find.byKey(const ValueKey('premiumFreeNote')), findsNothing);
      expect(find.byKey(const ValueKey('premiumBenefitsNote')), findsOneWidget);
    });

    testWidgets('広告非表示だけの購入では、まだ紹介カードが出る', (tester) async {
      final service = _service()..restorable = const EntitlementState(hasNoAds: true);
      await _pump(tester, _app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('購入を復元'));
      await tester.pumpAndSettle();

      expect(find.text('広告非表示を購入済みです'), findsOneWidget);
      expect(find.text('プレミアムでできること'), findsOneWidget);
    });

    testWidgets('プレミアム購入後は紹介カードが消える', (tester) async {
      await _pump(tester, _app(_service()));
      await tester.pumpAndSettle();
      expect(find.text('プレミアムでできること'), findsOneWidget);

      await tester.tap(find.text('¥1,500'));
      await tester.pumpAndSettle();

      expect(find.text('プレミアムを購入済みです'), findsOneWidget);
      expect(find.text('プレミアムでできること'), findsNothing);
      expect(find.byKey(const ValueKey('premiumBenefitsNote')), findsNothing);
    });
  });

  group('学習履歴のCSV（ファイル保存）', () {
    final fixedNow = DateTime(2026, 10, 20, 9);

    /// 履歴を端末内保存に仕込む（pump の前に呼ぶ）。履歴の読み込みは実際の非同期なので settle で待つ。
    void seedHistory() {
      SharedPreferences.setMockInitialValues({
        'ukalab_infosecmanage_history_v1': encodeHistory([
          ProgressRecord(
            qid: 'q1',
            subjectId: 's1',
            correct: true,
            at: DateTime(2026, 10, 9, 10),
            topicId: 'ch1',
          ),
        ]),
      });
    }

    Future<void> settle(WidgetTester tester) async {
      // 設定画面は履歴を押したときに初めて読むので、先に読み込みを始めておく。
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)))
          .read(historyProvider);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
    }

    Future<void> tapDownload(WidgetTester tester) async {
      final tile = find.byKey(const ValueKey('downloadHistoryCsv'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('履歴があれば、BOM付きUTF-8のCSVを所定のファイル名で保存に渡す', (tester) async {
      final calls = <({List<int> bytes, String fileName, String mimeType})>[];
      seedHistory();
      await _pump(tester, _app(
        _service(),
        now: () => fixedNow,
        saver: ({required bytes, required fileName, required mimeType, sharePositionOrigin}) async {
          calls.add((bytes: bytes, fileName: fileName, mimeType: mimeType));
          return true;
        },
      ));
      await settle(tester);
      await tapDownload(tester);

      expect(calls, hasLength(1));
      final call = calls.single;
      expect(call.fileName, 'ukalab_history_20261020.csv');
      expect(call.mimeType, 'text/csv');
      expect(call.bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(call.bytes.skip(3).toList());
      expect(csv, contains('日付,解答数,正答数,正答率(%),学習時間(分)'));
      expect(csv, contains('2026-10-09,1,1,100.0'));
      // 個人情報・問題IDの列を持たない。
      expect(csv, isNot(contains('q1')));
      expect(find.text('書き出しました'), findsOneWidget);
    });

    testWidgets('履歴が空なら保存を呼ばず、その旨を表示する', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var called = false;
      await _pump(tester, _app(
        _service(),
        now: () => fixedNow,
        saver: ({required bytes, required fileName, required mimeType, sharePositionOrigin}) async {
          called = true;
          return true;
        },
      ));
      await tester.pumpAndSettle();
      await tapDownload(tester);

      expect(called, isFalse);
      expect(find.text('まだ学習履歴がありません。'), findsOneWidget);
    });

    testWidgets('保存に失敗したら、失敗の文言を表示する', (tester) async {
      seedHistory();
      await _pump(tester, _app(
        _service(),
        now: () => fixedNow,
        saver: ({required bytes, required fileName, required mimeType, sharePositionOrigin}) async =>
            throw StateError('fail'),
      ));
      await settle(tester);
      await tapDownload(tester);

      expect(find.text('書き出せませんでした'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('共有シートを閉じたとき（false）は、完了の文言を出さない', (tester) async {
      seedHistory();
      await _pump(tester, _app(
        _service(),
        now: () => fixedNow,
        saver: ({required bytes, required fileName, required mimeType, sharePositionOrigin}) async =>
            false,
      ));
      await settle(tester);
      await tapDownload(tester);

      expect(find.text('書き出しました'), findsNothing);
      expect(find.text('書き出せませんでした'), findsNothing);
    });
  });
}
