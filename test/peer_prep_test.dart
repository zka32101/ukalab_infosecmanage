import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_infosecmanage/data/progress_store.dart';
import 'package:ukalab_infosecmanage/peer/peer_local_values.dart';
import 'package:ukalab_infosecmanage/peer/peer_stats_settings_store.dart';
import 'package:ukalab_infosecmanage/peer/peer_stats_settings_tile.dart';
import 'package:ukalab_infosecmanage/widgets/cert_prop.dart';

ProgressRecord _r(String qid, {int day = 1}) => ProgressRecord(
    qid: qid, subjectId: 's', correct: true, at: DateTime(2026, 10, day));

class _BrokenImage extends ImageProvider<_BrokenImage> {
  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration c) async => this;
  @override
  ImageStreamCompleter loadImage(_BrokenImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(Exception('broken')));
}

void main() {
  group('PeerStatsSettings', () {
    test('既定はOFF、保存と復元ができる', () async {
      SharedPreferences.setMockInitialValues({});
      const s = SharedPrefsPeerStatsSettings();
      expect(await s.isSharingEnabled(), isFalse);
      await s.setSharingEnabled(true);
      expect(await const SharedPrefsPeerStatsSettings().isSharingEnabled(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SharedPrefsPeerStatsSettings.key), isTrue);
      await s.setSharingEnabled(false);
      expect(await s.isSharingEnabled(), isFalse);
    });
  });

  group('PeerLocalValues', () {
    test('既存の値と一致し、延べとユニークは別に数える', () {
      final records = [_r('a'), _r('a', day: 2), _r('b')];
      final v = PeerLocalValues.from(
        progress: const ProgressState(streakDays: 5),
        records: records,
        examDate: DateTime(2026, 12, 6, 13, 30),
      );
      expect(v.streakDays, 5);
      expect(v.totalAnswers, 3);
      expect(v.uniqueQuestions, 2);
      expect(v.examDate, DateTime(2026, 12, 6));
      expect(PeerLocalValues.from(progress: const ProgressState(), records: const []).examDate,
          isNull);
    });
  });

  group('設定スイッチ', () {
    test('本番では非表示（フラグはfalse）', () => expect(kPeerStatsSettingsVisible, isFalse));

    testWidgets('ウィジェットは表示でき、操作で保存される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: PeerStatsSettingsTile())),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('参加しなくても、集計は見られます'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(await const SharedPrefsPeerStatsSettings().isSharingEnabled(), isTrue);
    });
  });

  group('PeerStatsCard（モック値）', () {
    testWidgets('スナップショットを渡すと表示される', (tester) async {
      const snap = PeerStatsSnapshot(
        asOf: '2026-10-15',
        activeToday: 500,
        participants: 1000,
        totalQuestions: 50000,
        medianQuestions: 40,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeerStatsCard(
              snapshot: snap, strings: PeerStatsStrings.ja, clock: () => DateTime(2026, 10, 15)),
        ),
      ));
      expect(find.textContaining('500人'), findsWidgets);
    });
  });

  group('cert props', () {
    testWidgets('表示され、狭い幅・大きい文字でもあふれない', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2), size: Size(280, 600)),
          child: Scaffold(
            body: Row(children: const [
              Expanded(child: Text('うかラボ 情報セキュリティマネジメント')),
              SizedBox(width: 8),
              CertPropAccent(),
            ]),
          ),
        ),
      ));
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('画像の読込に失敗しても例外にせず、何も出さない', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CertPropAccent(imageOverride: _BrokenImage())),
      ));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
