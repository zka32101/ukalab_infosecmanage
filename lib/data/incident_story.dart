import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ukalab_core/ukalab_core.dart';

/// 「インシデント対応30分」(ストーリー型の体験。ukalab_boki の会社経営モードと同じ構造)のデータ。

/// 画面に出す、AI下書きであることの表示(`contentStatus` が ai-draft のシナリオにだけ出す)。
const String kIncidentStoryDraftNotice = '学習用の架空シナリオ(AI下書き・専門確認前)';

/// データに付ける AI 下書きの印(`contentStatus`)。
const String kIncidentContentStatusAiDraft = 'ai-draft';

/// `contentStatus` に許す値。空(キーなし)は通常コンテンツ(問題・用語・読み物と同じ表記)。
/// これ以外の値は品質ゲートで拒否する。
const Set<String> kIncidentAllowedContentStatuses = {'', kIncidentContentStatusAiDraft};

/// 無料で遊べるシナリオ(最初の2本)。残りはプレミアム限定。
const Set<String> freeIncidentScenarioIds = {
  'incident_30min-0001',
  'incident_30min-0002',
};

const String kIncidentStoryAsset = 'assets/experience/incident_30min_info_security.jsonl';

/// 学習コンテンツに使わない表現。
const List<String> kIncidentForbiddenWords = ['公式', '本試験相当', '過去問', '合格保証'];

/// コア側の [StoryScenario] に、アプリ側の追加項目(AI下書きの印・関連用語)を足したもの。
class IncidentScenario {
  const IncidentScenario({
    required this.story,
    required this.contentStatus,
    required this.termIds,
  });

  final StoryScenario story;

  /// 空(キーなし)= 通常コンテンツ、'ai-draft' = AI下書きの印つき。
  final String contentStatus;

  /// 既存の用語集の termId。画面の「関連用語」から用語カードを開く。
  final List<String> termIds;

  String get scenarioId => story.scenarioId;
  bool get isFree => freeIncidentScenarioIds.contains(scenarioId);
  bool get isAiDraft => contentStatus == kIncidentContentStatusAiDraft;
}

class ParsedIncidentScenarios {
  const ParsedIncidentScenarios(this.scenarios, this.issues);

  final List<IncidentScenario> scenarios;
  final List<ContentIssue> issues;
}

ParsedIncidentScenarios parseIncidentScenarios(String text) {
  final base = parseStoryScenariosJsonl(text);
  final issues = [...base.issues];
  final extras = <String, Map<String, dynamic>>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('//')) continue;
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic> && decoded['scenarioId'] is String) {
        extras[decoded['scenarioId'] as String] = decoded;
      }
    } on FormatException {
      // 構文の問題は parseStoryScenariosJsonl 側で報告済み。
    }
  }
  final scenarios = <IncidentScenario>[];
  for (final s in base.scenarios) {
    final j = extras[s.scenarioId] ?? const <String, dynamic>{};
    final ids = j['termIds'];
    scenarios.add(IncidentScenario(
      story: s,
      contentStatus: j['contentStatus'] is String ? j['contentStatus'] as String : '',
      termIds: ids is List ? [for (final e in ids) if (e is String) e] : const [],
    ));
  }
  return ParsedIncidentScenarios(scenarios, issues);
}

/// 配信前の品質ゲート。コアの検査に加えて、contentStatus(未知の値は拒否)・出典・禁止表現・関連用語の参照先を確かめる。
List<ContentIssue> validateIncidentScenarios(
  List<IncidentScenario> items, {
  required ExamConfig exam,
  required Iterable<String> termIds,
}) {
  final issues = <ContentIssue>[
    ...validateStoryScenarios([for (final i in items) i.story], exam: exam),
  ];
  final known = termIds.toSet();
  for (final item in items) {
    final s = item.story;
    void add(String code, String message) => issues.add(ContentIssue(s.scenarioId, code, message));
    if (!kIncidentAllowedContentStatuses.contains(item.contentStatus)) {
      add('unknown-content-status', '未知の contentStatus です: ${item.contentStatus}');
    }
    if (s.source != QuestionSource.original) add('not-original', 'source は original(自作)である必要があります');
    if (!s.sourceRef.contains('自作')) add('no-self-made', 'sourceRef に自作である旨がありません');
    if (item.termIds.isEmpty) add('no-terms', '関連用語(termIds)がありません');
    for (final id in item.termIds) {
      if (!known.contains(id)) add('unknown-term', '用語集にない termId: $id');
    }
    final all = jsonEncode(s.toJson());
    for (final w in kIncidentForbiddenWords) {
      if (all.contains(w)) add('forbidden-word', '使わない表現が含まれています: $w');
    }
  }
  return issues;
}

Future<List<IncidentScenario>> loadIncidentScenarios() async {
  final text = await rootBundle.loadString(kIncidentStoryAsset);
  final parsed = parseIncidentScenarios(text);
  if (parsed.issues.isNotEmpty) {
    throw StateError('インシデント対応30分のデータに不備があります: ${parsed.issues.first}');
  }
  return parsed.scenarios.where((s) => !s.story.disabled).toList();
}
