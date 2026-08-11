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

## 3.5 `AutoLayout`は「並び方向の高さ/幅」を中身に自動フィットしてくれない

実際に`ManualLayout`から`AutoLayout`へ全面書き換えたところ、**横方向(`FillPortions`)は
狙い通りレスポンシブになった**が、**縦方向は明示的に`Height`を渡さないとコンテナが
壊れた**(チャートやテーブルが消える、中身がオーバーフローする等)。

### 症状1: 縦積み(`LayoutDirection.Vertical`)コンテナに`Height`を書かないと中身が消える

`CategoryPanel`(縦積み、`Height`未指定)の中に`PieChart`+凡例を入れたところ、
パネルだけ異常に高くなり、肝心のチャート・凡例が丸ごと表示されなくなった。
**CSSのflexboxのような「中身に自動フィット(hug contents)」はしてくれない。**
縦積みコンテナは`Height`を明示するか、次項の方法で子から計算する。

同じ理由で、横積み(`LayoutDirection.Horizontal`)コンテナの中で**さらに縦積みの
子コンテナが複数並ぶ**構造(例: 凡例の行を`grpLegendRow1`〜`5`として縦に並べた場合)
でも、**その各行コンテナ自身に`Height`が無いと、1行目しか表示されず残りが消える**。
「一番外側の縦コンテナだけ気をつければいい」のではなく、**ネストしたすべての縦積み
コンテナで同じ注意が必要**。

### 症状2: 子に`Height`を明示的に書いても、隠れた`LayoutMinHeight`のデフォルト値でオーバーフローする

ヘッダー行(`Height: =64`固定)の中に`grpHeaderLeft`(ロゴ+タイトルをまとめた横積み
コンテナ、`Height`を明示的に書かず中身[32px]に任せていた)を置いたところ、
ヘッダーの高さ64pxを超えてコンテンツが下にはみ出した。

Studioのプロパティパネルで実機確認したところ、**`AutoLayout`コンテナの子には
`LayoutMinHeight`が既定で`100`(!)入っている**ことが判明した(YAML側で明示的に
書いていなくても、Studio側でこの既定値が効く)。中身の実際の高さ(32px)より
このデフォルト最小高さ(100px)の方が大きいため、それが優先されて親をはみ出す。

**対策**: 「親の高さが既に確定しているコンテナの直下の子」については、`Height`を
決め打ちするのではなく `AlignInContainer: =AlignInContainer.Stretch` を使う。
これは子の高さを「常に親の高さに追従させる」という宣言になるため、`LayoutMinHeight`
の既定値と衝突しようがなくなる。

```yaml
# ❌ 子にHeightを書かない(または書いても隠れたLayoutMinHeight:100と衝突しうる)
grpHeaderLeft:
  Control: GroupContainer
  Variant: AutoLayout
  Properties:
    FillPortions: =0
    LayoutDirection: =LayoutDirection.Horizontal
    LayoutAlignItems: =LayoutAlignItems.Center

# ✅ 親(Height確定済み)に合わせてStretch
grpHeaderLeft:
  Control: GroupContainer
  Variant: AutoLayout
  Properties:
    FillPortions: =0
    AlignInContainer: =AlignInContainer.Stretch
    LayoutDirection: =LayoutDirection.Horizontal
    LayoutAlignItems: =LayoutAlignItems.Center
```

ただし`Stretch`が使えるのは「親の高さが確定している(≒行の高さが決まっている)」場合限定。
KPIカード行やチャートパネルのように、**親(行)の高さ自体が中身から逆算されるべき**
場所では使えない。

### 症状1・2への根本対策: 子コントロールの`.Height`を式で参照して親の`Height`を計算する

縦積みパネルの`Height`をただの数値(`Height: =280`)としてハードコードすると、
後で中の要素を1つ増減させたときに手計算をやり直すのを忘れて静かにズレる。
**代わりに子コントロールの`.Height`プロパティを式で参照して合計する**と、中身が
変わっても自動的に追従するので保守性が上がる(Power Fxはコントロール名を通じて
他コントロールのプロパティを参照でき、循環参照にならない限り問題ない)。

```yaml
# ❌ ハードコードした数値。中身を変えると手計算をやり直す必要がある
CategoryPanel:
  Properties:
    Height: =280

# ✅ 子の.Heightを式で参照する。中身が変わっても自動追従する
CategoryPanel:
  Properties:
    # 40 = PaddingTop(20) + PaddingBottom(20)。ここだけは定数でよい
    Height: =40 + grpCatHeader.Height + 16 + grpCatBody.Height
grpCatHeader:
  Properties:
    Height: =CategoryTitle.Height
grpCatBody:
  Properties:
    Height: =CategoryChart.Height
```

**まとめ**: `AutoLayout`を使うときの高さの決め方は3パターンに整理できる。

| コンテナの種類 | 高さの決め方 |
|---|---|
| 親の高さが確定している行の直下の子(ヘッダー内の要素など) | `AlignInContainer.Stretch` |
| 高さが中身依存の縦積みパネル・カード | 子コントロールの`.Height`を式で参照して合計(ハードコードしない) |
| 単純な葉ノード(アイコン・ラベル等) | 実測に基づく固定`Height`でよい |

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
