import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_infosecmanage/services/startup_safety.dart';

import 'test_support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('initAdGateOrNoAds', () {
    test('リリースでテスト広告IDが残っていても例外にならず、広告なしで続行する', () async {
      // 素の AdGate.init は StateError（これが起動時クラッシュの原因）。
      expect(
        () => AdGate.init(
          config: const AdConfig(
            unitIds: AdUnitIds(
              banner: 'ca-app-pub-3940256099942544/6300978111',
              interstitial: 'ca-app-pub-3940256099942544/1033173712',
              rewarded: 'ca-app-pub-3940256099942544/5224354917',
            ),
          ),
          adsHidden: () => false,
          backend: FakeAdsBackend(),
          isRelease: true,
        ),
        throwsStateError,
      );

      final gate = await initAdGateOrNoAds(
        init: () => AdGate.init(
          config: const AdConfig(
            unitIds: AdUnitIds(
              banner: 'ca-app-pub-3940256099942544/6300978111',
              interstitial: 'ca-app-pub-3940256099942544/1033173712',
              rewarded: 'ca-app-pub-3940256099942544/5224354917',
            ),
          ),
          adsHidden: () => false,
          backend: FakeAdsBackend(),
          isRelease: true,
        ),
      );
      expect(gate.banner(BannerPlacement.home), isA<SizedBox>());
      expect(await gate.maybeShowInterstitial(InterstitialTrigger.sessionEnd), isFalse);
      expect(await gate.showRewarded(), isFalse);
    });

    test('初期化に成功したときは、そのゲートをそのまま返す', () async {
      final ok = await testAdGate();
      final gate = await initAdGateOrNoAds(init: () async => ok);
      expect(identical(gate, ok), isTrue);
    });

    test('任意の例外でも握りつぶして広告なしにする', () async {
      final gate = await initAdGateOrNoAds(init: () async => throw Exception('sdk'));
      expect(await gate.maybeShowInterstitial(InterstitialTrigger.sessionEnd), isFalse);
    });
  });

  group('revenueCatKeyFor', () {
    String? key({
      bool web = false,
      bool android = false,
      bool ios = false,
      String g = '',
      String a = '',
    }) =>
        revenueCatKeyFor(isWeb: web, isAndroid: android, isIOS: ios, googleKey: g, appleKey: a);

    test('Android は Google のキー、iOS は Apple のキーを使う', () {
      expect(key(android: true, g: 'G', a: 'A'), 'G');
      expect(key(ios: true, g: 'G', a: 'A'), 'A');
    });

    test('キー未指定なら null（仮の購入サービスのまま）', () {
      expect(key(android: true, a: 'A'), isNull);
      expect(key(ios: true, g: 'G'), isNull);
      expect(key(android: true), isNull);
      expect(key(ios: true), isNull);
    });

    test('Web・その他のプラットフォームは常に null', () {
      expect(key(web: true, android: true, g: 'G', a: 'A'), isNull);
      expect(key(g: 'G', a: 'A'), isNull);
    });
  });
}
