# うかラボ 情報セキュリティマネジメント

情報セキュリティマネジメント試験（SG）対策アプリ。**IPA（独立行政法人情報処理推進機構）とは無関係の非公式アプリ**です。

## 位置づけ

```
うかラボ 情報セキュリティマネジメント（本リポジトリ） → ukalab_core v0.69.0 / app_common_kit v3.5.0
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
  questions/info_security.jsonl        問題（科目A 754問・科目B 288問）
  terms/info_security.jsonl            用語 318語
  experience/reading_info_security.jsonl 科目別の解説読み物
  features/                            試験当日チェックリスト・更新ログ
lib/                                   画面・保存（ITパスポート版と同構成）
```

`topicId`（科目A）: 情報セキュリティの考え方 / リスク / ISMS / インシデント / 脅威 / 技術対策 / ネットワーク / 法務 / 監査・内部統制 / 管理・委託 / 物理・環境 / 関連規格・機関 / セキュア開発 / クラウド・IoT / 人的対策 / IT基礎（DB・RAID・稼働率・TCP/UDP など）。
`topicId`（科目B）: ルール策定 / リスク評価 / インシデント対応 / アクセス管理 / 委託・クラウド / テレワーク / 物理・廃棄 / 規格・認証 / セキュア開発 / クラウド設定。

科目Bの長文事例（約220〜280字の事例文に4〜5問の設問）は34セット137問。コアが共通の事例文を持てないため、各設問の問題文の先頭に事例文を含め、`tags` に `scenario:sNN`（事例の識別子）を付けている。コアが事例のまとまりに対応した時に、同じ事例の設問をまとめて出題できる。

## 開発

```bash
flutter pub get
flutter analyze
flutter test
dart run ukalab_core:validate_content assets/exam/info_security.json --subtopic-scope=subject --terms assets/terms/info_security.jsonl assets/questions/info_security.jsonl
python3 docs/audit/verify_expansion.py   # 件数・ID重複・正解範囲・選択肢重複・偏りの確認（基準コミットを引数に渡すと追加のみかも確認）
```

## 現状

- 問題1,042問（目標1,000問程度に到達）・用語318語は**全て自作の初期サンプル（運営者確認前の仮データ）**。追加分（`info_security-0954`〜`1037` の84問と用語12語、および `1038`〜`1073` の科目B 36問）も仮データで専門確認前。公開前に一次資料での裏取りと運営者確認が必要（確認の優先順は `docs/content_review_checklist.md`）。IPAの過去問・シラバスは転載していない。
- 広告はテスト用ID（Google 公式）。課金は、ビルド時に `RC_GOOGLE_KEY`（Android）／`RC_APPLE_KEY`（iOS）を `--dart-define` で渡したビルドだけ RevenueCat が有効で、それ以外は `FakeEntitlementService`（実際の決済なし）。リリースビルドにテスト用IDが残ると `AdGate` の初期化が失敗し、起動は止めずに広告なしで続行する設計（`lib/services/startup_safety.dart`）。ストア向けビルドでの実機確認は未確認。
- アイコンは盾と鍵のシンボルに差し替え済み（うかラボ共通テンプレート。最終デザインは要確認）。パッケージID（`com.yourwish.ukalab.infosecmanage`）は本番用に確認が必要。
