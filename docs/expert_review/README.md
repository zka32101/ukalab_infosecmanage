# 専門家レビュー対象（AI下書き・未確認）

> **確認済み（2026-10-28）**: 専門家による確認でOKとなり、問題・用語・読み物の `ai-draft` タグ計202件を外した（`sourceRef` は「AI下書き・専門家確認済み」に更新）。体験教材「インシデント対応30分」の `contentStatus: ai-draft`（8本）は別項目のため今回は対象外。以下は確認前の記録として残す。

- 対象: 科目B追加分 36問（info_security-1038〜1073。データ全体も仮データ）
- 必要な専門性: 情報処理安全確保支援士／情報セキュリティマネジメント合格者
- 一覧: `review_ai_draft.csv`（UTF-8 BOM付き。Excel で開ける。末尾3列「判定(OK/修正/削除)」「コメント」「根拠」は空欄）
- 依頼文・確認観点・反映方法・範囲外事項: ukalab_core の `docs/expert_review_requests.md` と `docs/expert_review_session_handover.md`

## 運用ルール
- `ai-draft` タグは専門家の「OK」が出るまで外さない。広告表現（別の観点で出題 等）の根拠にも数えない。
- 判定が出た問題だけ別PRで反映（`contentVer` 更新）。「OK」のみタグを外す。「削除」は `disabled: true` か行削除。
- 記録するのは確認日（年月）と確認者区分のみ。氏名・所属・連絡先は記録しない。
- CSV の再生成: `python3 <core>/tools/export_review_csv.py <jsonl> --tag ai-draft -o docs/expert_review/review_ai_draft.csv`

## 追加分（2026-10・拡充ドラフト）: info_security-1074〜1133（60問）＋インシデント対応シナリオ4本
- 内容: 難易度3の問題60問（科目A 36問・科目B 24問=事例6セット s35〜s40）と、体験教材「インシデント対応30分」の第5〜8話（incident_30min-0005〜0008）。すべて `ai-draft`・自作の仮データ。
- チェックリスト: `review_checklist_additions_202610.csv`（ID・要確認観点・優先度。判定・コメント・根拠は空欄）。問題文と選択肢は `review_ai_draft_additions_202610.csv`。シナリオ本文は `assets/experience/incident_30min_info_security.jsonl`。
- 優先度「高」は、法令の整理・用語の定義・計算・正答の一意性を先に見てほしいもの。
- 既存の専門家確認待ちドラフト（#53/#54）とは別の範囲。同じ `assets/questions/info_security.jsonl` は末尾追記のみ。

## 追加分（2026-10・状況判断型20問）: info_security-1134〜1153
- 内容: 短い状況文から判断を選ぶ4択20問（科目A・難易度2）。解説に「判断理由」と「別場面の補足」を含む。すべて `ai-draft`・自作の仮データ。
- チェックリスト: `review_checklist_situational_202610.csv`、問題文と選択肢: `review_ai_draft_situational_202610.csv`。判定・コメント・根拠は空欄。
- 優先度「高」は法令（個人情報・著作権・営業秘密）とリスク対応の整理。条文番号や期限などの数値は入れていない。
- **専門家の確認前。マージ前にレビューを受けること。** 同じ `assets/questions/info_security.jsonl` は末尾追記のみ。

## 追加分（2026-10・状況判断型20問 第2弾）: info_security-1154〜1173
- 内容: 第1弾と別の場面（テレワーク・私物端末、ログと証跡保全、脆弱性対応、教育・内部不正、事業継続・バックアップ、なりすましメール、委託先監査）の4択20問（科目A・難易度2中心、一部3）。すべて `ai-draft`・自作の仮データ。
- チェックリスト: `review_checklist_situational_2_202610.csv`、問題文と選択肢: `review_ai_draft_situational_2_202610.csv`。判定・コメント・根拠は空欄。
- 優先度「高」は難易度3（脆弱性・サポート終了機器の扱い、監視の周知、事業継続の優先順位、委託先監査）。条文番号や期限などの数値は入れていない。
- **専門家の確認前。マージ前にレビューを受けること。** 同じ `assets/questions/info_security.jsonl` は末尾追記のみ。
