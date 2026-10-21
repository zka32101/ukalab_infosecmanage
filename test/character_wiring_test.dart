import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_infosecmanage/data/character_wiring.dart';

ProviderContainer _container(EntitlementService service) {
  final c = ProviderContainer(overrides: [
    entitlementServiceProvider.overrideWithValue(service),
    ...characterOverrides(),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('appId は info_security', () {
    final c = _container(FakeEntitlementService());
    expect(c.read(characterAppIdProvider), 'info_security');
  });

  test('無料は false、プレミアムは true（権利状態に追従）', () async {
    final service = FakeEntitlementService(
      availableOffers: const [
        EntitlementOffer(id: 'premium', productId: 'p', title: 't', priceString: '¥1'),
      ],
      grantOnPurchase: const {'p': EntitlementState(hasPremium: true)},
    );
    final c = _container(service);
    final sub = c.listen(characterPremiumProvider, (_, __) {});
    addTearDown(sub.close);
    await c.read(entitlementStateProvider.future);
    expect(c.read(characterPremiumProvider), isFalse);
    await service.purchaseOffer('premium');
    await Future<void>.delayed(Duration.zero);
    expect(c.read(characterPremiumProvider), isTrue);
  });
}
