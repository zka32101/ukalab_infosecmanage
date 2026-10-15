import 'dart:io';

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_infosecmanage/main.dart';

void main() {
  testWidgets('起動画面にアイコンと背景色が渡る', (tester) async {
    await tester.pumpWidget(MaterialApp(home: buildLaunchSplash()));
    final splash = tester.widget<StartupSplash>(find.byType(StartupSplash));
    expect(splash.appIconAsset, kLaunchIconAsset);
    expect(splash.backgroundColor, kLaunchBackground);
    expect(splash.appIconSize, kLaunchIconSize);
    expect(find.byType(Image), findsWidgets);
  });

  test('起動画面のアイコンが存在し pubspec に宣言され、ネイティブ背景色と一致する', () {
    expect(File(kLaunchIconAsset).existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains(kLaunchIconAsset));
    final colors = File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    final hex = kLaunchBackground.toARGB32().toRadixString(16).substring(2).toUpperCase();
    expect(colors, contains('name="launch_background_color">#$hex<'));
  });
}
