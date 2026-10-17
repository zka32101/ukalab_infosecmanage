import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_infosecmanage/data/mock_exam_quota.dart';
import 'package:ukalab_infosecmanage/data/review_schedule.dart';

ReviewItem _item(String qid, DateTime dueAt) => ReviewItem(
      qid: qid,
      stage: 0,
      dueAt: dueAt,
      lastReviewedAt: dueAt.subtract(const Duration(days: 1)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('期限の来た復習に答えると、1日の復習の回数に数える(無料枠は10問)', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await reviewSchedulerStore.write([for (var i = 0; i < 12; i++) _item('q$i', today)]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(reviewScheduleProvider.notifier);
    await notifier.reload();
    for (var i = 0; i < 12; i++) {
      await notifier.applyResult('q$i', correct: true, now: now);
    }
    final free = await todayReviewQuota(isPremium: false);
    expect(free.used, 10); // 上限で止まる
    expect(free.remaining, 0);
    expect((await todayReviewQuota(isPremium: true)).remaining, isNull); // プレミアムは無制限
  });

  test('期限前の問題や、予定にない問題は数えない', () async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    await reviewSchedulerStore.write([_item('later', tomorrow)]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(reviewScheduleProvider.notifier);
    await notifier.reload();
    await notifier.applyResult('later', correct: true, now: now);
    await notifier.applyResult('unknown', correct: true, now: now);
    expect((await todayReviewQuota(isPremium: false)).used, 0);
  });
}
