import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/foundation.dart';

import 'no_ads_backend.dart';

/// 広告の初期化に失敗しても起動を止めない。
///
/// リリースビルドでテスト広告ユニットIDが残っていると `AdGate.init` が [StateError] を投げる
/// （広告SDKの初期化失敗も同様）。そのままだと起動時に落ちるため、理由をログに出して
/// 「広告を出さない [AdGate]」で続行する。購入・学習機能には影響しない。
Future<AdGate> initAdGateOrNoAds({
  required Future<AdGate> Function() init,
}) async {
  try {
    return await init();
  } catch (e) {
    debugPrint('広告を無効にして起動を続けます（AdGate の初期化に失敗）: $e');
    return _noAdsGate();
  }
}

/// 広告を出さない [AdGate]（[NoAdsBackend]・広告ユニットIDなし・常に非表示）。
Future<AdGate> _noAdsGate() => AdGate.init(
      config: const AdConfig(unitIds: AdUnitIds(banner: '', interstitial: '', rewarded: '')),
      adsHidden: () => true,
      backend: NoAdsBackend(),
      isRelease: false,
    );

/// RevenueCat の公開SDKキーを選ぶ。使えるキーが無ければ null（仮の購入サービスで動く）。
///
/// Web は常に null。Android は [googleKey]、iOS は [appleKey]（ビルド時の `--dart-define`）。
String? revenueCatKeyFor({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
  required String googleKey,
  required String appleKey,
}) {
  if (isWeb) return null;
  final key = isAndroid ? googleKey : (isIOS ? appleKey : '');
  return key.isEmpty ? null : key;
}
