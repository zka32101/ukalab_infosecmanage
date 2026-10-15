import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'peer_stats_settings_store.dart';

/// 参加スイッチを設定画面に出すか。
///
/// 送信側がこのアプリにまだ無いため、false のまま（本番では表示しない）。
/// スイッチを出すと「送られる」と誤解されるので、送信を実装して接続するまで true にしない。
const kPeerStatsSettingsVisible = false;

/// 「みんなの学習状況」への参加スイッチ（説明付き）。
class PeerStatsSettingsTile extends ConsumerStatefulWidget {
  const PeerStatsSettingsTile({super.key});

  @override
  ConsumerState<PeerStatsSettingsTile> createState() => _PeerStatsSettingsTileState();
}

class _PeerStatsSettingsTileState extends ConsumerState<PeerStatsSettingsTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    ref.read(peerStatsSettingsProvider).isSharingEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _set(bool v) async {
    setState(() => _enabled = v);
    await ref.read(peerStatsSettingsProvider).setSharingEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('みんなの学習状況に参加'),
      subtitle: const Text(
        'オンにすると、連続学習日数・解いた問題数・試験日だけを、個人を特定できない形で集計に加えます。'
        '参加しなくても、集計は見られます。',
      ),
      value: _enabled,
      onChanged: _set,
    );
  }
}
