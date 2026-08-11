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

## 3.5 `AutoLayout`の高さ/幅ルール(何度も実地でハマった末の結論)

`ManualLayout`から`AutoLayout`へ全面書き換えたところ、**横方向(`FillPortions`)は
狙い通りレスポンシブになった**が、縦方向(高さ)で何度も同じ種類の不具合(チャートや
テーブルが消える、中身がオーバーフローする、下部が見切れる)を踏んだ。何度も原因を
掘り下げた結果、**「起点」を機械的に判定できるレベルまで法則が固まった**ので、
そのまま手順として書く。

### 核心ルール: `FillPortions: =0` を書いたら、その場で必ず `Height` も書く

**`FillPortions`が0(伸縮しない固定サイズ要素)は、中身に自動フィット(CSSのflexboxで
言う"hug contents")してくれない。** 対して `FillPortions` が1以上(伸縮する要素。
KPIカードや`ModernCard`など)は、伸縮計算のロジックの中で高さが正しく自動算出される。
実際、KPIカード(`FillPortions: =1`)は一度も`Height`を書かずに毎回正しく表示されたが、
同じ画面内の`FillPortions: =0`の行(タイトル行・チャート行・下段行)はすべて高さが
壊れた(0になって消える、逆に大きくなりすぎて中身がはみ出す)。

**やること**: `FillPortions: =0` と書いたら、**同じ`Properties`ブロックの中に必ず
`Height`(横積みコンテナの内部で伸縮しない子の場合は`Width`も)を明示する。**
「あとで直す」ではなく、`FillPortions: =0`を書いた瞬間にセットで書く癖をつける。
ネストの深さは関係なく、**`FillPortions: =0`が現れるたびに毎回**必要(1箇所直しても、
別の階層の`FillPortions: =0`が同じ理由で壊れる)。

```yaml
# ❌ FillPortions: =0 なのに Height がない → 自動フィットされず壊れる
grpKpiRow:
  Properties:
    FillPortions: =0
    LayoutDirection: =LayoutDirection.Horizontal

# ✅ FillPortions: =0 とHeightは必ずセットで書く
grpKpiRow:
  Properties:
    FillPortions: =0
    LayoutDirection: =LayoutDirection.Horizontal
    Height: =186
```

### 落とし穴1: `LayoutMinHeight`の隠れたデフォルト値`100`が`Height`より優先される

Studioのプロパティパネルで実機確認したところ、**`AutoLayout`コンテナの子には
`LayoutMinHeight`が既定で`100`(!)入っている**ことが判明した(YAML側で明示的に
書いていなくても、Studio側でこの既定値が効く)。**この値は`Height`より優先される
下限**なので、`Height: =64`のように100より小さい値を書いても、実際には100pxとして
描画され、親からはみ出す。`AlignInContainer: =AlignInContainer.Stretch`(子の高さを
親に追従させる)を使っても、**`LayoutMinHeight`が優先されて`Stretch`が効かない
ことがある**(実機で確認済み)。

**対策**: `FillPortions: =0`の要素には、`Height`と一緒に**必ず`LayoutMinHeight: =0`
(横方向で問題が出る場合は`LayoutMinWidth: =0`も)を明示して、隠れたデフォルトを
無効化する。** `Stretch`を使う場合も同様に`LayoutMinHeight: =0`とセットで書く。

```yaml
# ✅ Height/Stretchだけでなく、LayoutMinHeight: =0も必ずセットで書く
grpHeaderLeft:
  Control: GroupContainer
  Variant: AutoLayout
  Properties:
    FillPortions: =0
    LayoutMinHeight: =0
    AlignInContainer: =AlignInContainer.Stretch
    LayoutDirection: =LayoutDirection.Horizontal
    LayoutAlignItems: =LayoutAlignItems.Center
```

`AlignInContainer.Stretch`が使えるのは「親の高さが確定している(≒行の高さが決まって
いる)」場合限定。KPIカード行やチャートパネルのように、**親(行)の高さ自体が中身から
逆算されるべき**場所では使えない(その場合は上の核心ルール通り、行自体に実測ベースの
`Height`を書く)。

### 落とし穴2: 子の`.Height`を式で参照する高さ計算は、多段参照や`Max()`と組み合わせると`0`になることがある

縦積みパネルの`Height`を、子コントロールの`.Height`を式で参照して合計する
(`Height: =40 + grpCatHeader.Height + 16 + grpCatBody.Height`のように書く)と、
中身を増減させても手計算をやり直さずに済み保守性が上がる **……はずだったが、
実際には特定の組み合わせで評価が壊れて`0`になり、コンテンツが消えることが実機で
確認された。**

具体的に壊れたパターン: `grpTitleRow`(横積み)の`Height`を
`=Max(grpTitleLeft.Height, grpTitleRight.Height)` と書いたところ、Studioの数式バーで
`Max(grpTitleLeft.Height, grpTitleRight.Height) = 0` と表示され、タイトル行が丸ごと
消えた。`grpTitleLeft.Height`自身も`=PageTitle.Height + 4 + PageSubtitle.Height`という
**式**であり、「式で計算された高さを、さらに別の式(しかも`Max()`)から参照する」という
**多段の参照**になっていた。一方、同じ多段参照でも`CategoryPanel`(縦積み、単純な
足し算)や`RecentItemsPanel`は問題なく動いた。**`Horizontal`コンテナの高さを複数の
子から`Max()`で計算するパターンだけ相性が悪い**ようで、条件を厳密に切り分けられて
いない(=まだ完全には理解できていない)。

**対策(暫定)**: 子の`.Height`参照はできる限り**1段まで**にとどめる(参照先が
リテラルの`Height`を持つ葉ノードである場合は安全だった)。`Horizontal`コンテナの
`Height`を`Max()`で複数の子から計算するパターンは避け、**実測した数値をハードコード
する**方が確実(保守性は落ちるが、動くことを優先する)。

```yaml
# ❌ 横積みコンテナの高さをMax()+多段の子.Height参照で計算 → 0になって消えることがある
grpTitleRow:
  Properties:
    Height: =Max(grpTitleLeft.Height, grpTitleRight.Height)

# ✅ 実測してハードコードする(確実に動く)
grpTitleRow:
  Properties:
    Height: =56
```

### 落とし穴3: `ManualLayout`ラッパー内で負の`X`/`Y`を使うと見切れる

通知アイコンの右上にバッジを重ねるような「アイコンの角にバッジを重ねる」表現を
`ManualLayout`のラップコンテナ + 負の`Y`(`Y: =-6`など、親の上端からはみ出す位置)で
作ったところ、**バッジの一部が見切れて表示された。** `ManualLayout`コンテナは
自分の範囲外を描画しないため、負の座標は使わない。ラップコンテナ自体を少し大きめに
確保し、中の要素をすべて`0`以上の座標に収める。

### 落とし穴4: `AlignInContainer`未指定だと上寄せ(または開始位置)になり、`LayoutAlignItems.Center`が効かないことがある

親コンテナに`LayoutAlignItems: =LayoutAlignItems.Center`を指定していても、**子側で
`AlignInContainer`を明示していないと、その子だけ中央揃えされず上端に張り付くことが
あった**(ヘッダー内のベルアイコン・アバター等)。親の`LayoutAlignItems`は「子が
`AlignInContainer`を指定しなかった場合の初期値」程度にしか信用できない。

**対策**: `FillPortions: =0`の子で、かつ縦方向(または横方向)の中央揃えを期待する
場合は、**親に頼らず子ごとに`AlignInContainer: =AlignInContainer.Center`を明示する。**

```yaml
# ❌ 親のLayoutAlignItems.Centerだけに頼る → 上寄せになることがある
grpBellWrap:
  Properties:
    FillPortions: =0
    Width: =32
    Height: =40

# ✅ 子ごとに明示する
grpBellWrap:
  Properties:
    FillPortions: =0
    AlignInContainer: =AlignInContainer.Center
    Width: =32
    Height: =40
```

### 落とし穴5: `GroupContainer`には既定で影(`DropShadow`)が暗黙に付いており、入れ子にすると二重に見える

`GroupContainer`には`DropShadow`(`None`/`Light`/`Semilight`/`Semibold`/`Regular`/
`Bold`/`ExtraBold`)というプロパティが実在するが、**YAMLで何も指定しないと既定で
何らかの影が付く。** カードの外枠(`Fill`付きの`GroupContainer`)の中に、さらに
`Fill`付きの`GroupContainer`(アイコンの背景色の四角など)をネストすると、**両方に
既定の影が付いてしまい、カードの中にもう1枚カードがあるような二重の影**になって
見た目が崩れる。

**対策**: 「本当に影を見せたい一番外側のカード面」だけに`DropShadow`を明示的に
設定し(例: `=DropShadow.Semilight`)、**それ以外の全ての`GroupContainer`には
`DropShadow: =DropShadow.None`を明示する。** 「暗黙のデフォルトに任せない」という
点は本セクションの他の落とし穴と共通の教訓。

```yaml
# ✅ 外側のカードだけ影を残し、中のネストしたコンテナは明示的にNoneにする
KpiCard1:
  Control: GroupContainer
  Properties:
    DropShadow: =DropShadow.Semilight   # ここだけ影を見せる
    Fill: =RGBA(255, 255, 255, 1)
  Children:
    - grpKpi1IconWrap:
        Control: GroupContainer
        Properties:
          DropShadow: =DropShadow.None   # ネストした子は必ずNoneにする
          Fill: =RGBA(224, 222, 253, 1)
```

### まとめ: `AutoLayout`で画面を組むときのチェックリスト

1. `FillPortions: =0`を書いたら、**同じ場所に`Height`と`LayoutMinHeight: =0`を必ずセットで書く**(横方向で必要なら`LayoutMinWidth: =0`も)
2. `FillPortions`が1以上の要素は、高さを気にしなくてよい(伸縮計算で自動的に正しくなる)
3. 親の高さが確定しているコンテナの直下の子は`AlignInContainer.Stretch`(+`LayoutMinHeight: =0`)でもよい
4. 子の`.Height`を式で参照して親の高さを計算するのは**1段まで**。`Horizontal`コンテナで`Max()`を使う場合は特に注意し、怪しければ実測値をハードコードする
5. `ManualLayout`ラッパー内で子を重ねるときは、負の座標を使わない
6. 中央揃えしたい`FillPortions: =0`の子には`AlignInContainer: =AlignInContainer.Center`を親任せにせず明示する
7. すべての`GroupContainer`に`DropShadow: =DropShadow.None`をデフォルトで書き、影を見せたい一番外側のカード面だけ明示的に上書きする
8. これらを全部満たしても、**必ずPlayモードで実際の見た目を確認する**(コンパイルは通ってしまうため)

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
