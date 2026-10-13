# うかラボ 情報セキュリティマネジメント

情報セキュリティマネジメント試験（SG）対策アプリ。**IPA（独立行政法人情報処理推進機構）とは無関係の非公式アプリ**です。

## 位置づけ

```
うかラボ 情報セキュリティマネジメント（本リポジトリ） → ukalab_core v0.65.0 / app_common_kit v3.1.0
```

試験定義・問題・用語・解説読み物・ストア設定だけを持つ薄いリポジトリです。構成は同じIPA系の先行アプリ [ukalab_it_passport](https://github.com/zka32101/ukalab_it_passport) を土台にしています。

## 試験定義（暫定）

| 項目 | 値 |
|---|---|
| 方式 | CBT（通年実施） |
| 科目A（知識） | 四肢択一 48問 |
| 科目B（事例） | 事例問題 12問 |
| 試験時間 | 120分（2科目合計） |
| 合格基準 | 総合評価点 600点／1,000点（IRT採点）。本アプリでは正答率60%で近似 |

IRTによる採点は再現できないため、模擬試験の合否は目安です。値はIPAの公式情報で要確認（`PRELAUNCH_CHECKLIST.md`）。

## 構成

```
assets/
  exam/info_security.json              ExamConfig（科目A・科目B）
  questions/info_security.jsonl        問題（科目A 187問・科目B 48問）
  terms/info_security.jsonl            用語 110語
  experience/reading_info_security.jsonl 科目別の解説読み物
  features/                            試験当日チェックリスト・更新ログ
lib/                                   画面・保存（ITパスポート版と同構成）
```

`topicId`（科目A）: 情報セキュリティの考え方 / リスク / ISMS / インシデント / 脅威 / 技術対策 / ネットワーク / 法務 / 監査・内部統制 / 管理・委託。
`topicId`（科目B）: ルール策定 / リスク評価 / インシデント対応 / アクセス管理 / 委託・クラウド / テレワーク。

## 開発

```bash
flutter pub get
flutter analyze
flutter test
dart run ukalab_core:validate_content assets/exam/info_security.json --subtopic-scope=subject --terms assets/terms/info_security.jsonl assets/questions/info_security.jsonl
```

## 現状

- 問題235問・用語110語は**全て自作の初期サンプル（運営者確認前の仮データ）**。公開前に大幅な追加（目標1,000問程度）と一次資料での裏取りが必要。IPAの過去問・シラバスは転載していない。
- 広告はテスト用ID、課金は `FakeEntitlementService`（仮）。
- アイコンは盾と鍵のシンボルに差し替え済み（うかラボ共通テンプレート。最終デザインは要確認）。パッケージID（`com.yourwish.ukalab.infosecmanage`）は本番用に確認が必要。
