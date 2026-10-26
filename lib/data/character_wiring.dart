import 'package:app_common_kit/app_common_kit.dart' show entitlementStateProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart'
    show characterAppIdProvider, characterPremiumProvider;

/// ukalab_core に登録される、このアプリの appId（`UkalabCert.infoSecurity`）。
const String kCharacterAppId = 'info_security';

/// 資格専用キャラの表示に必要な override。
/// プレミアムかどうかは entitlement の変化に追従して導出する（固定値にしない）。
List<Override> characterOverrides() => [
      characterAppIdProvider.overrideWithValue(kCharacterAppId),
      characterPremiumProvider.overrideWith(
        (ref) => ref.watch(entitlementStateProvider).valueOrNull?.hasPremium ?? false,
      ),
    ];
