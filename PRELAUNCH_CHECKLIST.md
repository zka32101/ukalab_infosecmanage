# うかラボ 情報セキュリティマネジメント — 公開前チェックリスト

凡例: `content` データ・一次資料の裏取り / `ops` 本番環境・運用の差し替え / `legal` 商標・法務

## コンテンツ

- [ ] `content` 試験定義（科目A 48問・科目B 12問・120分・総合600/1000点）をIPAの公式情報で確認
- [ ] `content` 問題の大幅な追加（現在445問。目標1,000問程度）と、全問の運営者確認・出典の裏取り
- [ ] `content` 科目B（事例）は、長文シナリオ＋複数設問の形式を追加
- [ ] `content` 用語データ（195語）の拡充と運営者確認
- [ ] `content` シラバス最新版との出題範囲の突合（`docs/` に対応表を作成）
- [ ] `content` 解説読み物の拡充（現在2本）
- [ ] `content` 更新ログ（`assets/features/update_log.jsonl`）は空。公開時の内容を記入

## 本番環境・運用

- [ ] `ops` AdMob のアプリID・広告ユニットIDを発行して差し替え（現在はGoogle公式テスト用）
- [ ] `ops` RevenueCat のAPIキー取得（現在は `FakeEntitlementService`）。商品ID `info_security_noads` / `info_security_premium`
- [ ] `ops` アプリアイコンの最終デザイン確認（盾と鍵の仮デザインに差し替え済み）
- [ ] `ops` Firebase プロジェクトの作成と `firestore.rules` のデプロイ
- [ ] `ops` 価格の最終確認

## 商標・法務

- [ ] `legal` 「情報セキュリティマネジメント」表記の可否を確認し、非公式アプリである旨の表記を確認
- [ ] `legal` 公式過去問・IPAコンテンツの利用条件を確認（転載は確認前は行わない）
