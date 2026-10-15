import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart';

/// この資格（情報セキュリティマネジメント）に合わせて選んだ小物。
///
/// monitor: 監視・ログ・ダッシュボードなど、情報セキュリティの「運用・管理」を連想させるため。
const certProp = UkalabCertProp.monitor;

/// ホームの見出し脇に置く控えめな飾りの小物。
///
/// 操作はできない飾りなので [IgnorePointer] で包み、タップ領域の邪魔をしない。
/// 画像が読めなかったときはエラー表示にせず、何も出さない。
class CertPropAccent extends StatelessWidget {
  const CertPropAccent({super.key, this.size = 44, this.prop = certProp, this.imageOverride});

  final double size;
  final UkalabCertProp prop;

  /// テストで画像の読み込み失敗を再現するための差し替え。通常は使わない。
  final ImageProvider? imageOverride;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Image(
            image: imageOverride ?? UkalabProps.certImage(prop),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
