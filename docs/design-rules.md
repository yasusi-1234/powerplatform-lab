# 設計ルール(共通化方針)

同じような画面/ロジックを画面ごとに毎回書き下ろすのではなく、**Component(UI側)**と
**App.Formulasの名前付き関数(ロジック側)**の2つの手段で共通化する。命名規則は
[naming-conventions.md](naming-conventions.md)を参照。

---

## 1. Component化する

### 1.1 判断基準

- **2画面以上で同じ見た目・構造が繰り返されている**もの
- 中身(テキスト・値・色)だけが違い、**構造は同じ**もの
- 将来的に画面が増えても**同じパターンが再登場すると予想できる**もの(サイドナビ等)

逆に、1画面にしか出てこないもの・構造が微妙に違うものは無理にComponent化しない
(共通化コストの方が高くつく)。

### 1.2 現状のアプリから拾った具体的な候補

簡易承認アプリの3画面(`RequestListScreen`/`RequestDetailScreen`/`RequestFormScreen`)を
見て、実際に重複しているパターン:

| Component候補 | 現状の重複箇所 | Input Properties(案) |
|---|---|---|
| **Header**(ヘッダーバー) | `grpHeader`/`grpHeaderDtl`/`grpHeaderFrm`が3画面ともほぼ同一(ロゴ+アプリ名+ユーザー名/ロール+アバター) | `UserName`, `UserRole` |
| **StatusBadge**(ステータスバッジ) | `RowStatusBadge`/`DetailStatusBadge`/`InfoStatusBadge`/`AutoInfoStatusBadge`。4箇所で同じ`Switch(Status, ...)`によるThemeColor切り替えを重複記述 | `Status`(Text) |
| **InfoRow**(ラベル+値の横並び行) | 詳細画面`grpInfoRow1-4`、登録画面`grpAutoInfoRow1-4`。ラベル+値をSpaceBetweenで並べる同一構造が8箇所 | `Label`, `Value` |
| **FieldBlock**(縦積みラベル+値、下線付き) | 詳細画面`DetailCard`内の`grpFieldTitle`/`grpFieldContent`/`grpFieldRemarks`/`grpFieldApplicant`/`grpFieldRequestDate`/`grpFieldUpdateDate` + 個別の`Divider*`。6箇所+区切り線 | `Label`, `Value`, `ShowDivider` |
| **BackRow**(戻るボタン+区切り+画面タイトル) | 詳細画面`grpBackRow`、登録画面`grpBackRowFrm`。「← 申請一覧に戻る \| ○○画面」の同一構造 | `Title`, `OnBack` |
| **FormFieldLabel**(必須アスタリスク付きラベル) | 登録画面`TitleFieldLabel`+`TitleFieldRequired`、`ContentFieldLabel`+`ContentFieldRequired` | `Label`, `Required` |
| **CharCounter**(文字数カウンター) | 登録画面`TitleCounter`/`ContentCounter`/`RemarksCounter`。「0/100」形式の表示が3箇所 | `CurrentLength`, `MaxLength` |
| **HistoryRow**(履歴1件分の表示) | 詳細画面`grpHistoryRow1-3`。実データ接続後はGalleryの1テンプレートになるので、実質的にはここで自動的にComponent相当の再利用構造になる想定 | `ActionType`, `ActionUser`, `ActionDate`, `Comment` |

### 1.3 未検証の注意点

このプロジェクトではまだCanvas Apps MCP経由でComponent(`.pa.yaml`の
`ComponentDefinitions`)を作った実績が無い。通常の画面`.pa.yaml`とは別の
書式になるはずなので、**いきなり全部Component化せず、まず1つ(StatusBadgeなど
影響範囲が小さいもの)で試して`compile_canvas`が通るか確認してから、他に
展開する。** うまくいかない場合の代替は「画面ごとにテンプレート的にコピー
して使う」に留める。

---

## 2. 関数化する(`App.Formulas`の名前付き関数)

### 2.1 判断基準

- 複数画面で**同じ判定・変換ロジック**を書きそうなもの(権限判定、表示整形)
- 名前を見ただけで何をするか分かること

### 2.2 数式関数(Formula Function) と ビヘイビア関数(Behavior Function)

`App.Formulas`で定義する関数は2種類ある。JSで言う**純粋関数(pure function)**と
**副作用のある関数(impure function)**の対比と同じ:

```js
// 純粋関数: 入力から結果を計算するだけ。外部に影響しない
let statusColor = (status) => { return status === "承認" ? "green" : "gray"; }

// 副作用のある関数: console.logのように外部(コンソール/DB/画面)に影響する処理を含む
let approve = (request) => { patchList(request); console.log("approved"); }
```

| 種別 | 中身 | 呼べる場所 | Power Fxでの例 |
|---|---|---|---|
| **数式関数(Formula Function)** | 純粋な計算だけ(副作用なし) | どこでも(`Text`/`Color`等のプロパティからも) | `StatusColor`, `IsApprover` |
| **ビヘイビア関数(Behavior Function)** | `Patch`/`Set`/`Navigate`等の**副作用を含む処理** | `OnSelect`のようなビヘイビア系プロパティのみ | `ApproveRequest`, `SubmitDraft` |

**実機で検証済みの構文注意点**: ビヘイビア関数(`: Void`を返す関数)は、
本体を`{ }`(波カッコ)で囲む必要がある。数式関数のように`=`の後へ直接式を
書くだけだと、「`void`の戻り値の型は、動作のユーザー定義関数でのみサポート
されています」というエラーになる。

```powerfx
# ❌ 波カッコが無いとエラーになる(Studioで実機確認済み)
ApproveRequest(request: Record): Void =
    Patch(T_Request, request, {Status: "承認"});

# ✅ 波カッコで囲むと通る
ApproveRequest(request: Record): Void = {
    Patch(T_Request, request, {Status: "承認"});
};
```

**実機で確認済みの制限: `UpdateContext`はユーザー定義関数の中では使えない。**
`Func(val: Text): Void = {Set(a, ""); UpdateContext({a: ""});}`のように書くと、
「ユーザー定義関数の内部で関数 UpdateContext を使用することはできません。」と
明確にエラーになる(画面スコープかどうかに関係なく、UDF内では一律禁止)。
画面ローカルの状態を関数内で扱いたい場合は、`UpdateContext`は使わず、
`Set`(グローバル変数)またはデータソースへの`Patch`/`Collect`で代替する。

**実機で確認済み: レコード型を戻り値にしたい場合、`Record`という型を裸で
書くのではなく、`Type()`でUser Defined Type(UDT)として先に宣言してから
使う。** `Dynamic`型(構造不定のデータ用。`UntypedObject`に近い)にレコード
リテラルをそのまま返そうとすると、「宣言した関数の戻り値タイプ`Dynamic`が、
関数本文の戻り値タイプ`Record`と一致しません」というエラーになる。

```powerfx
# ❌ Dynamic型にレコードリテラルは直接返せない
Func2(val: Date, val2: Text): Dynamic = {a: Text("")};

# ✅ Type()でレコードの形を先に宣言し、その型名を戻り値に使う(実機確認済み)
MyRecordType := Type({a: Text});
Func2(val: Date, val2: Text): MyRecordType = {a: Text("")};
```

**実機で確認済み: レコード型引数のフィールドを渡し忘れても(部分的なレコード
リテラルを渡しても)エラーにならず、その列は`Blank`として扱われる。**

```powerfx
MyRecordType2 := Type({a: Text, b: Text});
Func3(val: MyRecordType2): Text = If(IsBlank(val.a), "空要素でした", val.a);

Func3({b: ""})  // → aを渡していないが型エラーにならず、"空要素でした" が返る
```

実装上の意味: SharePointから取得したレコードのうち、まだ値が入っていない列
(新規作成直後で`ApprovalComment`が空、等)をそのまま関数に渡しても、型不一致で
落ちる心配はない。`IsBlank()`で安全に判定できる。

### 2.3 現状の仕様から拾った具体的な候補

| 関数名(案) | 種別 | 用途 | 現状の記述(重複予定箇所) |
|---|---|---|---|
| `IsApprover(email: Text): Boolean` | 数式関数 | ログインユーザーが承認者かどうか判定 | `!IsBlank(LookUp(M_Approvers, ApproverUser.Email = email && IsActive = true))`(要求仕様書7.2に既出) |
| `IsOwnRequest(request: Record): Boolean` | 数式関数 | 自分の申請かどうか判定 | `request.Applicant.Email = User().Email` |
| `CanEditRequest(request: Record): Boolean` | 数式関数 | 編集可能かどうか(自分の申請 かつ 承認済でない) | `IsOwnRequest(request) && request.Status <> "承認"` |
| `StatusColor(status: Text): Color` | 数式関数 | ステータス文字列 → Badgeの`ThemeColor`変換 | 一覧/詳細/登録画面で4回重複している`Switch(Status, "承認", ..., "差戻し", ...)` |
| `FormatRequestDate(dateValue: DateTime): Text` | 数式関数 | 日時表示フォーマットの統一 | 各画面でバラバラに書きそうな日付整形 |
| `ApproveRequest(request: Record)` | ビヘイビア関数 | 承認処理(`T_Request`更新 + `T_RequestHistory`追記) | `ApproveButton.OnSelect` |
| `RejectRequest(request: Record, comment: Text)` | ビヘイビア関数 | 差戻し処理(同上) | `RejectButton.OnSelect` |
| `SubmitRequest(request: Record, isDraft: Boolean)` | ビヘイビア関数 | 一時保存/申請処理(`RequestDate`の初回のみセットするロジックを含む) | `SaveDraftButton`/`SubmitButton`の`OnSelect` |

命名はPower Fx組み込み関数に合わせてPascalCase、真偽値を返す数式関数は
`Is`/`Can`から始める。ビヘイビア関数は動詞から始める(`Approve`/`Reject`/`Submit`)。

### 2.4 ロジックの置き場所: Component内 か `App.Formulas` か

**基本方針: ロジックはComponentの中に埋め込まず、`App.Formulas`の関数に出す。**
Componentは「見た目・構造」の再利用に専念させ、中のボタン等の`OnSelect`からは
`App.Formulas`の関数(`ApproveRequest(request)`等)を呼ぶだけにするか、Behavior
プロパティ経由で外から注入する(2.のJS例で言う「関数を分離する」考え方)。
理由: ロジックをComponent内に閉じ込めると、**そのComponentを使わない場所から
同じ処理を呼びたくなったときに再利用できない**(将来の一括承認ボタン等)。

**例外: Componentを「役割を持つクラス」のような単位として大量に作る場合は、
ロジックをComponent内に持たせてもよい。** 例えば「申請カード」のように、
同じ構造+同じ振る舞いのインスタンスを何十個も並べるような使い方をする場合、
無理に外へロジックを追い出さず、Component自体を1つの完結した単位として
設計する方が自然なことがある。この判断基準は明確な線引きが難しいため、
**「他のComponentや画面から同じロジックを呼びたくなるかどうか」**を都度考えて
判断する(呼びたくなる可能性があるなら`App.Formulas`側、そのComponent専用の
振る舞いで完結するなら内部に持たせてもよい)。

---

## 3. 運用ルール

- 新しい画面・項目を作るときは、**先に上の表を確認し、該当するComponent/関数が
  あればそれを使う。無ければ「2画面目で重複したタイミング」で初めてComponent化/
  関数化を検討する**(1回しか使わないものを先回りして共通化しない)。
- Component/関数を追加・変更したら、このファイルの表を更新する。
