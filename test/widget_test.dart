import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_infosecmanage/main.dart';

import 'test_support.dart';

// MascotWidget は animate: true が既定のため、disableAnimations なしでは
// アニメーションが回り続けて pumpAndSettle がタイムアウトする。
Future<Widget> _app() async => ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
        entitlementServiceProvider.overrideWithValue(FakeEntitlementService(
          availableOffers: const [
            EntitlementOffer(
              id: 'noads',
              productId: 'info_security_noads',
              title: '広告非表示',
              priceString: '¥480',
            ),
          ],
          grantOnPurchase: const {
            'info_security_noads': EntitlementState(hasNoAds: true),
          },
        )),
        adGateProvider.overrideWithValue(await testAdGate()),
        examStatsServiceProvider.overrideWithValue(FakeExamStatsService()),
      ],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const UkalabInfoSecurityApp(),
      ),
    );

void main() {
  testWidgets('起動して問題データを読み込み、ホーム画面が表示される', (tester) async {
    // assets からの読み込みは実際の非同期I/Oのため、pump だけでは
    // fake async のタイミングと競合してタイムアウトすることがある。
    // runAsync で実際の非同期ガップを許可してから反映させる。
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('うかラボ 情報セキュリティマネジメント'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('学ぶ'), findsOneWidget);
    expect(find.text('模擬'), findsOneWidget);
  });

  testWidgets('用語集を開いて検索し、用語カードが開く', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('用語集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用語集'));
    await tester.pumpAndSettle();
    expect(find.text('用語を検索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ファイアウォール');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'ファイアウォール'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'ファイアウォール'));
    await tester.pumpAndSettle();
    expect(find.byType(TermCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TermCard),
        matching: find.text('通信をルールで許可・遮断する仕組み'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('最短ルートプランナーを開くと今日やるタスクが出る（科目は2つ）', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('最短ルートプランナー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最短ルートプランナー'));
    await tester.pumpAndSettle();

    expect(find.byType(RoutePlannerWidget), findsOneWidget);
    expect(find.text('今日やる2つ'), findsOneWidget);
  });

  testWidgets('100問ペース走を開くと説明と開始ボタンが出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('100問ペース走'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100問ペース走'));
    await tester.pumpAndSettle();

    expect(find.text('ペース走を始める'), findsOneWidget);
  });

  testWidgets('設定タブで購入すると購入済み表示になる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('広告非表示'), findsOneWidget);

    await tester.tap(find.text('¥480'));
    await tester.pumpAndSettle();
    expect(find.text('広告非表示を購入済みです'), findsOneWidget);
  });

}
