import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 画面の中央に置きたいが、文字が大きい・画面が狭いときは縦にスクロールして
/// 内容が切れないようにする入れ物。
///
/// `Center` + `Column(mainAxisSize: min)` は、内容が画面の高さを超えると
/// RenderFlex overflow（下が切れる）になる。これで包むと、収まるうちは従来どおり
/// 中央、収まらないときはスクロールできる。
class ScrollableCenter extends StatelessWidget {
  const ScrollableCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// タイトルを折り返して全文を見せる AppBar。
///
/// 標準の AppBar は題名を 1 行・末尾省略で描くので、狭い画面や文字を大きくした設定では
/// 題名が途中で切れる。ここでは題名が 1 行に収まらないときだけ、必要な行数ぶん
/// ツールバーを高くして折り返す（収まるときは標準の AppBar と同じ見た目・高さ）。
/// 呼び出しは `build` の中から（画面幅と文字倍率を見るため）。
AppBar wrappingAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) {
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
  final media = MediaQuery.of(context);
  final canPop = ModalRoute.of(context)?.canPop ?? false;
  // 左の戻るボタン(56) + 題名の左右の余白(16 + 16) + 右の操作ボタン(48 x 個数) を除いた幅。
  final reserved =
      (canPop ? kToolbarHeight : 0) + 32 + 48.0 * (actions?.length ?? 0);
  final available = math.max(80.0, media.size.width - reserved);
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: media.textScaler,
    maxLines: 4,
  )..layout(maxWidth: available);
  final needed = painter.height + 16;
  painter.dispose();
  return AppBar(
    title: Text(
      title,
      maxLines: 4,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    ),
    actions: actions,
    toolbarHeight: math.max(kToolbarHeight, needed),
  );
}
