# Canvas App YAML(.pa.yaml) 作成ルール

Canvas Apps MCP(`canvas-app`スキル)でYAMLを生成・編集する際に従うルール。
本リポジトリでの実地検証(TestSolution / TestApp2)で実際に発生した不具合をもとに
まとめている。今後も検証を重ねながらこのリポジトリ独自にブラッシュアップしていく。

プロパティ名・enum値は最終的には必ず `describe_control` で確認するのが大原則。
このドキュメントは「確認を忘れて事故りやすいポイント」を先回りしてまとめたもの。

---

## 1. コントロールごとにプロパティ体系が全く違う

コントロールは大きく **Classic系** / **FluentV9系** / **React系** の3系統があり、
同じ役割のプロパティでも名前が違う。**似た名前・似た用途のプロパティ名を、別の
コントロールに流用しない。**

| コントロール | Family | 背景色 | 文字色 | 文字サイズ |
|---|---|---|---|---|
| `Label` | Classic | `Fill` | `Color` | `Size` |
| `Rectangle` / `GroupContainer` | Classic | `Fill` | — | — |
| `Button` | FluentV9 | `BasePaletteColor` (+`Appearance`) | `FontColor` | `FontSize` |
| `Badge` | FluentV9 | `BasePaletteColor` (+`ThemeColor`/`Appearance`) | `FontColor` | `FontSize` |
| `ModernCard` | React | `Fill` | `TitleColor`/`SubtitleColor`/`DescriptionColor` | `TitleSize`等 |

`Button`/`Badge` に Classic系のつもりで `Fill`/`Color`/`Size` を書くと
`Unknown property` エラーになる(実際に発生・修正済み)。**新しいコントロールを
使う前に、必ず `describe_control` で背景色・文字色・サイズのプロパティ名を確認する。**

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
形式(プレフィックスの有無・型名そのもの)がバラバラ。値の候補だけでなく**型名も**
`describe_control` で確認してから書く。

## 2. アイコン名は自由文字列 → 実在しない名前は「丸(circle)」になる(エラーにならない)

`Icon`/`ModernIcon` の `Icon` プロパティは列挙型ではなく**自由文字列**。Power Appsの
モダンコントロールで実際に使えるのは **181種類の限定セット** のみで、それ以外の名前を
書いても**コンパイルエラーにはならず、単なる丸アイコンとして表示される**。見た目で
気づくまで気づけないので厄介(実機で確認済み: `CubeShape`, `Contact`, `AddCircle`,
`ArrowRepeatAll`, `DataBarVertical` は全て実在せず丸になった)。

全181種類の一覧: [Power Apps FluentIcon Reference](https://github.com/thepowerappsguy/power-apps-fluenticon-reference)

このリポジトリで**実在確認済み**のアイコン名(用途の参考。随時追記する):

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
| 一覧・箇条書き | `DocumentBulletList` |
| 分析・グラフ系(専用アイコンが無い場合の代替) | `PulseSquare` |

大文字小文字も区別される。新しいアイコンが必要な場合は上記リファレンスで存在を
確認してから使う(推測で名前を作らない)。

## 3. `ManualLayout` の絶対座標は「想定した画面幅」とズレるとはみ出す

参考画像(モックアップ)通りに再現しようとして、画面全体を`ManualLayout`+`X`/`Y`の
絶対座標で組んだ結果、**想定した画面幅(1536px)と実際のアプリの画面幅(1366px)が
一致せず、右側のコンテンツ(4枚目のKPIカード、右側パネル、ヘッダー右側の通知
アイコン等)が画面からはみ出して見切れる**、という不具合が実際に発生した。

原因は主に2つ:

- ヘッダーの右寄せ要素を「画面幅から逆算した固定X」で置いた(例: `X: =1300`)。
  想定した画面幅と実際の画面幅が違うとズレる。
- 繰り返し構造(KPIカードの並び、テーブルの行など)を個別の絶対座標で計算した。
  1箇所の幅を変えると、後続の要素のXを全部計算し直す必要があり、ミスが起きやすい。

**本来の対策**: 参考画像を見たら、まず「ヘッダー」「サイドナビ」「メインコンテンツ
(タイトル行/カード行/チャート行/テーブル行)」のようにゾーンへ分解し、各ゾーンを
`AutoLayout`(`LayoutDirection`/`LayoutGap`/`FillPortions`/`LayoutJustifyContent.SpaceBetween`)
で組む。ピクセル位置をそのまま`ManualLayout`の`X`/`Y`に落とし込まない。

**今回の対応**: 実験用サンプルだったため、座標を実際の画面幅(1366px)に合わせて
再計算する応急処置で対応した。次回、本格的な画面を作る際は上記の`AutoLayout`方式を
最初から採用する。

## 4. `DataTable`(Classic)はYAMLの`Items`だけでは表示されないことがある

`DataTable`コントロールに`Items`だけを設定してPlayモードで確認したところ、
**「表示するアイテムがありません」と表示され、データがバインドされなかった**
(コンパイルはエラーなしで通過)。`DataTable`は列構成を別途Studio側で設定する前提の
挙動を持つ可能性があり、YAML経由の生成とは相性が悪そうだった。

→ **代替: `Gallery`(Vertical) + テンプレート内に`ThisItem.フィールド名`を参照する
`Label`を並べる方式**にしたところ、正常にデータが表示された。一覧・テーブル表現が
必要な場合は`DataTable`より`Gallery`を優先する。見出し行(ヘッダー)は別の`Label`行を
Galleryの上に静的に置き、**列位置(X/Width)を見出し行とGalleryのテンプレートで
必ず同じ値に揃える**(片方だけ直すと列がズレる)。

## 5. コレクションのフィールド名に日本語を使う場合

`ClearCollect`のレコードで日本語のフィールド名(`管理番号`, `備品名` 等)はクォートなしで
使用可能で、`ThisItem.管理番号` のようにドット記法でそのまま参照できる(コンパイル・
実行とも問題なし)。ただしフィールド名に `/` のようなPower Fx上の特殊文字を含めると
問題が起きる可能性があるため避ける(`貸出先/場所` ではなく `貸出先場所` にした)。

## 6. 作業フロー

1. 新しいコントロールを使う前に `list_controls` → `describe_control` で仕様を確認する
2. YAMLを書く(推測で書かない)
3. `compile_canvas` で検証する。エラーが出たら該当プロパティを再度 `describe_control` で
   確認してから直す
4. コンパイルが通っても安心しない。**Playモード(F5)で実際の見た目を確認する。**
   アイコンの丸表示、レイアウト崩れ、データバインドの失敗はコンパイルエラーには
   ならず、Playモードで見て初めて気づく種類の不具合だった

---

## 参考: 他プロジェクトの汎用ルール集

同じ手法(Canvas Apps MCP)で以前作った別プロジェクトに、配色パレット・命名規則・
`AutoLayout`設計・コントロール仕様リファレンスまで含んだより網羅的なルール集がある。
本格的に画面を作り込む際は目を通す価値がある:
[kaizen-irai-kanri-app / SCREEN_RENDERING_RULES_GENERIC.md](https://github.com/yasusi-1234/kaizen-irai-kanri-app/blob/main/SCREEN_RENDERING_RULES_GENERIC.md)
