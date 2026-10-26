# 専門家レビュー対象（AI下書き・未確認）

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
