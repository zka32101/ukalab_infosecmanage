import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart' show PeerStatsSettings;

/// 参加設定（既定OFF）を端末内に保存する [PeerStatsSettings] の実装。
///
/// 保存するのは ON/OFF の真偽値だけ。端末の識別子などは作らない・保存しない。
class SharedPrefsPeerStatsSettings implements PeerStatsSettings {
  const SharedPrefsPeerStatsSettings();

  static const key = 'ukalab_infosecmanage_peer_stats_sharing_v1';

  @override
  Future<bool> isSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> setSharingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, enabled);
  }
}

final peerStatsSettingsProvider =
    Provider<PeerStatsSettings>((ref) => const SharedPrefsPeerStatsSettings());
