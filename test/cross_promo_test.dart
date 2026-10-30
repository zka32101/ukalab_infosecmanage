import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/cross_promo.dart';
import 'package:ukalab_infosecmanage/data/cross_promo_config.dart';
import 'package:ukalab_infosecmanage/screens/settings_screen.dart';

import 'test_support.dart';

void main() {
  test('applicationId は ukalab_core の kUkalabAppIds に含まれる', () {
    expect(isUkalabAppId(kInfoSecurityApplicationId), isTrue);
    expect(kInfoSecurityApplicationId, 'com.yourwish.ukalab.infosecmanage');
  });

  testWidgets('掲載0件・Firebase未初期化でも、相互紹介セクションは例外なく何も表示しない', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UkalabCrossPromoSection(currentAppId: kInfoSecurityApplicationId)),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('他のアプリ'), findsNothing);
  });

  testWidgets('設定画面は、掲載0件でも壊れず、相互紹介の見出しも出ない', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(FakeEntitlementService(availableOffers: const [])),
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(UkalabCrossPromoSection), findsOneWidget);
    expect(find.textContaining('他のアプリ'), findsNothing);
  });
}
