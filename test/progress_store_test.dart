import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_infosecmanage/data/progress_store.dart';

ProviderContainer _container({DateTime Function()? clock}) {
  final c = ProviderContainer(
    overrides: [
      if (clock != null) progressClockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recordAnswer で正誤を記録する', () async {
    final c = _container();
    await c.read(progressProvider.notifier).recordAnswer('q1', correct: true);
    await c.read(progressProvider.notifier).recordAnswer('q2', correct: false);
    final state = c.read(progressProvider);
    expect(state.distinctAnswered, 2);
    expect(state.correctCount, 1);
  });

  test('recordMockResult(passed: true) で mockPassedEver が立つ', () async {
    final c = _container();
    expect(c.read(progressProvider).mockPassedEver, isFalse);
    await c.read(progressProvider.notifier).recordMockResult(passed: true);
    expect(c.read(progressProvider).mockPassedEver, isTrue);
  });

  test('recordMockResult(passed: false) は mockPassedEver を変えない', () async {
    final c = _container();
    await c.read(progressProvider.notifier).recordMockResult(passed: false);
    expect(c.read(progressProvider).mockPassedEver, isFalse);
  });

  test('一度 true になった mockPassedEver は false にならない', () async {
    final c = _container();
    await c.read(progressProvider.notifier).recordMockResult(passed: true);
    await c.read(progressProvider.notifier).recordMockResult(passed: false);
    expect(c.read(progressProvider).mockPassedEver, isTrue);
  });

  test('初めて学習した日は streakDays が1になる', () async {
    final c = _container(clock: () => DateTime(2026, 10, 1));
    await c.read(progressProvider.notifier).recordAnswer('q1', correct: true);
    final state = c.read(progressProvider);
    expect(state.streakDays, 1);
    expect(state.lastStudyDay, '2026-10-01');
  });

  test('同じ日に何度解答しても streakDays は変わらない', () async {
    final c = _container(clock: () => DateTime(2026, 10, 1));
    await c.read(progressProvider.notifier).recordAnswer('q1', correct: true);
    await c.read(progressProvider.notifier).recordAnswer('q2', correct: false);
    expect(c.read(progressProvider).streakDays, 1);
  });

  test('前日から続けていると streakDays が+1される', () async {
    var now = DateTime(2026, 10, 1);
    final c = _container(clock: () => now);
    await c.read(progressProvider.notifier).recordAnswer('q1', correct: true);
    now = DateTime(2026, 10, 2);
    await c.read(progressProvider.notifier).recordAnswer('q2', correct: true);
    final state = c.read(progressProvider);
    expect(state.streakDays, 2);
    expect(state.lastStudyDay, '2026-10-02');
  });

  test('2日以上空くと streakDays が1に戻る', () async {
    var now = DateTime(2026, 10, 1);
    final c = _container(clock: () => now);
    await c.read(progressProvider.notifier).recordAnswer('q1', correct: true);
    now = DateTime(2026, 10, 5);
    await c.read(progressProvider.notifier).recordAnswer('q2', correct: true);
    expect(c.read(progressProvider).streakDays, 1);
  });

  test('touchStudyDay は模擬試験の実施からも呼べる', () async {
    final c = _container(clock: () => DateTime(2026, 10, 1));
    await c.read(progressProvider.notifier).touchStudyDay();
    expect(c.read(progressProvider).streakDays, 1);
  });
}
