# 命名規則

このリポジトリで作るPower Platformアプリ(SharePoint Lists / Canvas App)全般に
適用する命名規則。特定のアプリ(簡易承認アプリ等)の実装を通じて実際に使った
パターンを、後から参照・再利用できるように定義したもの。

YAML記述時の注意点(プロパティ名の落とし穴等)は
[canvas-app-yaml-notes.md](canvas-app-yaml-notes.md)を参照。本ドキュメントは
「名前の付け方」だけを扱う。

---

## 1. SharePointリスト・列

### リスト名

英語PascalCase + プレフィックスで、リストの性質を先頭1文字で判別できるようにする。

| プレフィックス | 意味 | 例 |
|---|---|---|
| `T_` | トランザクションデータ(業務データの本体) | `T_Request`, `T_RequestHistory` |
| `M_` | マスターデータ(参照・判定用) | `M_Approvers` |

### 列名(内部名)

- 英語PascalCase(`RequestBody`, `ApprovalComment`など)。日本語は使わない。
- SharePoint標準列(`ID`/`Title`/`Created`/`Modified`/`Author`/`Editor`)と役割が
  重複する場合は、カスタム列を追加せず標準列を流用する(表示名だけ変更する)。
  例: `Title`列の表示名を「タイトル」に変更して使う。
- 真偽値(Yes/No型)は`Is`接頭辞: `IsActive`
- 日付列は`Date`接尾辞: `RequestDate`, `UpdateDate`, `ActionDate`
- 他リストのレコードを参照する列は、参照先のキー名 + 参照先リスト名を意識した
  単純な数値(Number)列にする(`RequestID`が`T_Request.ID`を指す、など)。
  SharePointのLookup型はCanvas Appsとの相性(委任・パフォーマンス)が悪いため
  極力避ける([canvas-app-yaml-notes.md](canvas-app-yaml-notes.md)参照)。

### 選択肢(Choice)の値

内部名ではなくユーザーが直接目にする表示値なので、**日本語のまま**でよい
(例: `未申請`/`申請中`/`承認`/`差戻し`)。無理に英語化しない。

---

## 2. Power Fx / Canvas App側

### 画面名

`{業務名}{画面の役割}Screen` の形。

```
RequestListScreen
RequestDetailScreen
RequestFormScreen
```

### コントロール名

**コントロールの種類ごとに接頭辞/接尾辞を統一する。** 同じ画面内はもちろん、
アプリ全体でコントロール名は一意である必要があるため([canvas-app-yaml-notes.md](canvas-app-yaml-notes.md)参照)、
複数画面で同じ役割のコントロールが繰り返し登場する場合は、画面ごとの短い
サフィックスを付けて衝突を避ける。

| 対象 | ルール | 例 |
|---|---|---|
| レイアウト用コンテナ(`GroupContainer`) | `grp`接頭辞 | `grpRoot`, `grpHeader`, `grpFilterRow`, `grpListCard` |
| ボタン | `Button`接尾辞 | `NewRequestButton`, `SubmitButton`, `BackButton` |
| アイコン(`ModernIcon`) | `Icon`接尾辞 | `HeaderLogoIcon`, `RowApplicantIcon` |
| テキスト入力(`ModernTextInput`) | 用途 + `Input`接尾辞 | `SearchInput`, `TitleInput`, `CommentInput` |
| ドロップダウン(`ModernDropdown`) | 用途 + `Dropdown`接尾辞 | `StatusDropdown` |
| 日付選択(`ModernDatePicker`) | 用途 + `Picker`接尾辞 | `DateStartPicker`, `DateEndPicker` |
| バッジ(`Badge`) | 用途 + `Badge`接尾辞 | `RowStatusBadge`, `DetailStatusBadge` |
| テキスト表示(`ModernText`) | 用途を表す名詞(装飾なし)。項目ラベルは`Label`接尾辞 | `PageTitle`, `TitleFieldLabel`, `InfoLabel1` |
| Galleryの行テンプレート内コントロール | `Row`接頭辞 | `RowTitle`, `RowStatusBadge`, `RowChevron` |
| 画面またぎで同名になりうるコントロール | 画面固有の短いサフィックスを付ける | 詳細画面は`Dtl`、登録画面は`Frm`(例: `grpHeaderDtl`, `BackButtonFrm`) |

複数画面で同じ役割の塊(ヘッダー等)を作る場合、最初に作る画面(基準画面)は
サフィックス無し、以降の画面は上表のサフィックスを付ける運用とする
(例: `RequestListScreen`はサフィックス無し、`RequestDetailScreen`は`Dtl`、
`RequestFormScreen`は`Frm`)。

### コレクション・変数・定数

| 種別 | 命名 | 例 |
|---|---|---|
| コレクション(`ClearCollect`等) | `col`接頭辞 | `colRequests` |
| グローバル変数(`Set`で書き換える可変な状態) | `gro`接頭辞 | `groCurrentUser`(例) |
| 画面ローカル変数(`UpdateContext`) | `loc`接頭辞 | `locIsEditing`(例) |
| 定数(`App.Formulas`で定義する読み取り専用の名前付き数式) | 全大文字SNAKE_CASE | `USER_INFO`(例) |

`gro`(可変・`Set`で更新される)と定数(不変・`App.Formulas`で定義)は性質が違うため、
接頭辞と大文字/小文字で明確に区別する。`OnStart`の`Set()`で書いていたグローバル
定数は、`App.Formulas`(名前付き数式)へ移行するのを基本とする(委任・再計算の
挙動がOnStartより安定するため)。

(このアプリでは現時点でコレクションのみ使用。実際に変数・定数を使うタイミングで
上記ルールを適用する。)

---

## 3. 簡易承認アプリでの命名実例(参考)

実際に上記ルールを適用した結果の一覧。今後別アプリを作る際のテンプレートとして
参照する。

| 対象 | 名前 |
|---|---|
| SharePointリスト | `T_Request`, `M_Approvers`, `T_RequestHistory` |
| 画面 | `RequestListScreen`, `RequestDetailScreen`, `RequestFormScreen` |
| コレクション | `colRequests` |
| コンテナ(一覧画面) | `grpRoot` → `grpHeader` / `grpMain` → `grpFilterRow` → `grpFilterInputs`, `grpListCard` → `grpTableHeader` |
| ボタン | `NewRequestButton`, `BackButton` / `BackButtonFrm`, `SubmitButton`, `ApproveButton`, `RejectButton` |
