# Canvas App YAML(.pa.yaml) 作成メモ

Canvas Apps MCP(`canvas-app`スキル)でYAMLを生成・編集するときに実際に踏んだ罠と、
確認済みの正しい書き方をまとめる。プロパティ名は必ず `describe_control` で確認するのが
大原則だが、ここには**繰り返し間違えやすいもの**だけ抜き出す。

> より体系的・網羅的なルール集が別プロジェクトに既にある:
> [kaizen-irai-kanri-app / SCREEN_RENDERING_RULES_GENERIC.md](https://github.com/yasusi-1234/kaizen-irai-kanri-app/blob/main/SCREEN_RENDERING_RULES_GENERIC.md)
> (配色・命名規則・AutoLayout設計・コントロール仕様リファレンスまで含む汎用版)。
> 本格的に画面を作るときはまずそちらを読む。ここは本リポジトリでの実地検証中に
> 追加で踏んだ罠・確認事項の記録。

## コントロールごとのプロパティ体系の違い(実際に踏んだもの)

コントロールは大きく **Classic系** / **FluentV9系** / **React系** に分かれ、同じ役割の
プロパティでも名前が違う。**推測で書かない。必ず `describe_control` で確認する。**

| コントロール | Family | 背景色 | 文字色 | 文字サイズ |
|---|---|---|---|---|
| `Label` | Classic | `Fill` | `Color` | `Size` |
| `Rectangle` / `GroupContainer` | Classic | `Fill` | — | — |
| `Button` | **FluentV9** | `BasePaletteColor`(+`Appearance`) | `FontColor` | `FontSize` |
| `Badge` | **FluentV9** | `BasePaletteColor`(+`ThemeColor`/`Appearance`) | `FontColor` | `FontSize` |
| `ModernCard` | React | `Fill` | `TitleColor`/`SubtitleColor`/`DescriptionColor` | `TitleSize`等 |

`Button`/`Badge` に `Fill`/`Color`/`Size` を書くと `Unknown property` エラーになる
(実際に発生・修正済み)。

### enum名にドット(`.`)が含まれる場合はクォートが必要

```yaml
# NG — YAML/PowerFxパーサーがそのまま解釈できずエラーになる
Appearance: =ButtonCanvas.Appearance.Primary
ThemeColor: =BadgeCanvas.ThemeColor.Danger

# OK — enum名部分を単一引用符で囲む
Appearance: ='ButtonCanvas.Appearance'.Primary
ThemeColor: ='BadgeCanvas.ThemeColor'.Danger
```

同じ「`Appearance`」というプロパティ名でも、コントロールによってenum型の完全修飾名の
形式(プレフィックスの有無)がバラバラなので、都度 `describe_control` で確認すること。

## アイコン名は自由文字列 → 実在しない名前は「丸(circle)」になる(エラーにならない)

`Icon`/`ModernIcon` の `Icon` プロパティは列挙型ではなく**自由文字列**。Power Appsの
モダンコントロールで実際に使えるのは **181種類の限定セット** のみで、それ以外の名前を
書いても**コンパイルエラーにはならず、単なる丸アイコンとして表示される**(実機で確認済み。
`CubeShape`, `Contact`, `AddCircle`, `ArrowRepeatAll`, `DataBarVertical` などは全て
実在せず丸になった)。

全181種類の一覧: [Power Apps FluentIcon Reference](https://github.com/thepowerappsguy/power-apps-fluenticon-reference)

このリポジトリの実験で**実在確認済み**のアイコン名(用途の参考):

| 用途 | Icon値 |
|---|---|
| ホーム / ダッシュボード | `Home` |
| 追加・新規登録 | `Add` |
| 設定・マスター | `Settings` |
| 削除 | `Delete` |
| 一覧・グリッド | `Grid`, `GridDots`, `Table` |
| データ・レポート | `Data`, `Database` |
| 通知・アラート | `Alert` |
| ヘルプ | `QuestionCircle` |
| 人物・アバター | `Person` |
| 更新・同期 | `ArrowClockwise`, `ArrowSync` |
| 時計・保留中 | `Clock`, `ClockAlarm` |
| 完了・チェック | `Checkmark`, `CheckmarkCircle` |
| 工具・メンテナンス | `Wrench`, `Toolbox` |
| 検索 | `Search` |
| 箱・在庫 | `Box`, `Cube` |

大文字小文字も区別される。新しいアイコンが必要な場合は上記リファレンスで存在を
確認してから使う(推測で名前を作らない)。

## ManualLayoutで絶対座標を使うときの罠(実際に発生)

参考画像を再現するために画面全体を`ManualLayout`+`X`/`Y`の絶対座標で組んだ結果、
**想定した画面幅(1536px)と実際のアプリの画面幅(1366px)が一致せず、右側のコンテンツ
(4枚目のKPIカード、クイックアクションパネル、ヘッダー右側の通知アイコン等)が
画面からはみ出して見切れる**、という不具合が実際に発生した。

原因と対策は上記の [SCREEN_RENDERING_RULES_GENERIC.md 第4章](https://github.com/yasusi-1234/kaizen-irai-kanri-app/blob/main/SCREEN_RENDERING_RULES_GENERIC.md#4-レイアウト原則pc前提)
にも同じパターンとして詳しく書かれている。要点:

- 参考画像通りに作りたい場合でも、ピクセル座標をそのまま`ManualLayout`に落とし込まない
- ヘッダーの右寄せ要素・繰り返し構造(サイドナビ項目・カードの並び・テーブル行)は
  本来`AutoLayout`(`FillPortions`・`LayoutJustifyContent.SpaceBetween`等)で組むべき
- 今回は実験用サンプルだったため、座標を実際の画面幅に合わせて再計算する応急処置で
  対応した(根本対応ではない)

## DataTable(Classic)はYAMLのItemsだけでは表示されないことがある

`DataTable`コントロールに`Items`だけを設定してPlayモードで確認したところ、
**「表示するアイテムがありません」と表示され、データがバインドされなかった**
(コンパイルはエラーなしで通過)。`DataTable`は列構成を別途Studio側で設定する前提の
挙動を持つ可能性があり、YAML経由の生成とは相性が悪そうだった。

→ **代替: `Gallery`(Vertical) + テンプレート内に`ThisItem.フィールド名`を参照する
`Label`を並べる方式**にしたところ、正常にデータが表示された。一覧・テーブル表現が
必要な場合は`DataTable`より`Gallery`を優先する。

## コレクションのフィールド名に日本語を使う場合

`ClearCollect`のレコードで日本語のフィールド名(`管理番号`, `備品名` 等)はクォートなしで
使用可能で、`ThisItem.管理番号` のようにドット記法でそのまま参照できる(コンパイル・
実行とも問題なし)。ただしフィールド名に `/` のようなPower Fx上の特殊文字を含めると
問題が起きる可能性があるため避ける(`貸出先/場所` ではなく `貸出先場所` にした)。
