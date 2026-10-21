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
    final service = FakeEntitlementService();
    final c = _container(service);
    final sub = c.listen(characterPremiumProvider, (_, __) {});
    addTearDown(sub.close);
    await c.read(entitlementStateProvider.future);
    expect(c.read(characterPremiumProvider), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // stream 購読の確立を待つ
    service.setState(const EntitlementState(hasPremium: true));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(characterPremiumProvider), isTrue);
  });
}
