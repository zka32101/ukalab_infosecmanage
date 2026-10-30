# 相互紹介（うかラボ8アプリ）

他のうかラボアプリを設定画面で案内する。`cross_promo_kit` を `ukalab_core` の薄いラッパー経由で使う（独自実装はしない）。

## このアプリでの使い方

| 項目 | 内容 |
|---|---|
| applicationId | `com.yourwish.ukalab.infosecmanage`（`lib/data/cross_promo_config.dart` の `kInfoSecurityApplicationId`） |
| 起動時 | `lib/main.dart` で `unawaited(UkalabCrossPromo.init())`（Firebase 初期化と Remote Config 取得。失敗しても起動を止めない） |
| 表示場所 | 設定画面の末尾（`lib/screens/settings_screen.dart`） `UkalabCrossPromoSection(currentAppId: kInfoSecurityApplicationId)` |
| 対象 | 大人向けのため `isChildDirected` は付けない（保護者ゲートなし） |
| 掲載0件 | 何も表示しない |
| 出さない場所 | 問題・模擬試験・復習の最中には置かない（設定画面のみ） |

プレミアム／広告非表示の購入者にも表示する（自社アプリの案内であり、広告ではないため）。

## Remote Config（コードでは変更できない）

掲載リストは Firebase Remote Config のキー `cross_promo_apps`（JSON の配列）で配信する。
空（`[]`）または未設定の間は、アプリ側には何も表示されない。

- 掲載リストの正、検証と投入の手順は cross_promo_kit の `docs/cross_promo_apps.json` と `docs/ROLLOUT.md` を参照。
- 紹介は同じカテゴリ内のみ。うかラボの `category` は `うかラボ`。
- 項目は `id`（applicationId）/ `name` / `tagline` / `iconUrl` / `storeUrl` / `category`。

```json
[
  {
    "id": "<applicationId>",
    "name": "<アプリ名>",
    "tagline": "<ひとこと説明>",
    "iconUrl": "<アイコン画像のURL>",
    "storeUrl": "<ストアのURL>",
    "category": "うかラボ"
  }
]
```

`<...>` は実値に置き換える（実値はこのリポジトリに書かない）。公開を確認したアプリだけを載せる。
投入先の Firebase プロジェクトは運営判断。Android のビルドには `GOOGLE_SERVICES_JSON_BASE64`（README 参照）が必要。

## applicationId の一覧

`package:ukalab_core/cross_promo.dart` の `kUkalabAppIds` を参照。
