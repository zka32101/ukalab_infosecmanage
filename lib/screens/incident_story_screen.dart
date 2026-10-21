import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/incident_story.dart';
import '../widgets/overflow_safe.dart';

/// プレミアム限定シナリオを未購読でタップしたときの案内。
const String kIncidentPremiumNotice = 'このシナリオはプレミアムの機能です。設定から購入できます。';

/// 「インシデント対応30分」のシナリオ一覧。最初の2本は無料、残りはプレミアム限定
/// ([freeIncidentScenarioIds])。未購読でロック中のシナリオをタップしても画面には入らず、案内だけ出す。
class IncidentStoryListScreen extends ConsumerStatefulWidget {
  const IncidentStoryListScreen({super.key, required this.terms, this.scenariosFuture});

  final List<Term> terms;

  /// テスト用。省略時は assets から読み込む。
  final Future<List<IncidentScenario>>? scenariosFuture;

  @override
  ConsumerState<IncidentStoryListScreen> createState() => _IncidentStoryListScreenState();
}

class _IncidentStoryListScreenState extends ConsumerState<IncidentStoryListScreen> {
  late final Future<List<IncidentScenario>> _future =
      widget.scenariosFuture ?? loadIncidentScenarios();

  void _open(IncidentScenario scenario) {
    final entitlement = ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free;
    if (!scenario.isFree && !entitlement.hasPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kIncidentPremiumNotice)),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => IncidentStoryPlayScreen(scenario: scenario, terms: widget.terms),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // タップ時の read だけだと、読み込み中に「無料」と判定されるため、ここで購読しておく。
    ref.watch(entitlementStateProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: wrappingAppBar(context, 'インシデント対応30分'),
      body: FutureBuilder<List<IncidentScenario>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '読み込みに失敗しました: ${snapshot.error}');
          }
          final scenarios = snapshot.data!;
          if (scenarios.isEmpty) {
            return const EmptyState(message: '利用できるシナリオがありません。');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '架空の会社でセキュリティ事故が起きた想定で、最初の30分の判断を選びます。選んだあとに理由の解説が出ます。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                kIncidentStoryDraftNotice,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              for (final s in scenarios) ...[
                Card(
                  child: ListTile(
                    title: Text(s.story.title),
                    subtitle: Text(
                      '全${s.story.chapters.length}ステップ ・ ${s.isFree ? '無料' : 'プレミアム'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: s.isFree
                        ? const Icon(Icons.chevron_right)
                        : Icon(Icons.lock_outline, color: theme.colorScheme.outline),
                    onTap: () => _open(s),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 1シナリオを遊ぶ画面。判断→解説→結果の流れは共通部品 [StoryModeWidget] が担い、
/// ここでは AI 下書きの表示と、既存の用語集につながる「関連用語」を添える。
class IncidentStoryPlayScreen extends StatelessWidget {
  const IncidentStoryPlayScreen({super.key, required this.scenario, required this.terms});

  final IncidentScenario scenario;
  final List<Term> terms;

  Term? _term(String id) {
    for (final t in terms) {
      if (t.termId == id) return t;
    }
    return null;
  }

  void _openTerm(BuildContext context, Term term) {
    showTermCard(
      context,
      term: term.term,
      headline: term.headline,
      definition: term.definition,
      analogy: term.analogy,
      commonMistake: term.commonMistake,
      relatedTerms: [
        for (final id in term.relatedTermIds)
          if (_term(id) != null) RelatedTermRef(termId: id, label: _term(id)!.term),
      ],
      onRelatedTermTap: (nextId) {
        final next = _term(nextId);
        if (next == null) return;
        Navigator.of(context).pop();
        _openTerm(context, next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = scenario.story;
    final related = [
      for (final id in scenario.termIds)
        if (_term(id) != null) _term(id)!,
    ];
    return Scaffold(
      appBar: wrappingAppBar(context, s.title),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scenario.isAiDraft) ...[
                Text(
                  kIncidentStoryDraftNotice,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),
              ],
              StoryModeWidget(
                scenario: StoryScenarioSpec(
                  title: s.title,
                  description: s.description,
                  chapters: [
                    for (final c in s.chapters)
                      StoryChapterSpec(
                        situation: c.situation,
                        choices: [
                          for (final ch in c.choices)
                            StoryChoiceSpec(
                              choiceId: ch.choiceId,
                              text: ch.text,
                              isRecommended: ch.isRecommended,
                              feedback: ch.feedback,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('関連用語(タップで用語カード)', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in related)
                      ActionChip(label: Text(t.term), onPressed: () => _openTerm(context, t)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
