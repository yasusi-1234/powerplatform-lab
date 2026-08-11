# 研究メモ: Power Platform × AI開発

最終更新: 2026-08-11

## 研究テーマ

Power PlatformをAI(Claude)と組み合わせて開発する際、主に2つのアプローチが存在する。
この2つの違い・使い分けを研究する。

1. **Canvas Apps MCP**(`canvas-apps` 系スキル)
2. **Solution unpack/pack**(`pac solution unpack/pack`)

以下は現時点(調査ベース、実機検証はこれから)での整理。

---

## ① Canvas Apps MCP(canvas-apps系スキル)

- Canvas Authoring MCPを介して、対話的にCanvas Appの画面・コントロールを生成/編集する
- ソース形式は `.pa.yaml`
- **既に少し使ってみた実績あり**

### 印象(ユーザー所感)

- できあがるものの質は「すごい」と感じた
- ただし **生成に時間がかかるのが難点**

### わかっている制約

- 対象はCanvas Appのみ
- Power Automate(Flow)の作成はできない
- Solution全体(Flow・テーブル・接続等を含む)の一括管理は範囲外

---

## ② Solution unpack/pack(`pac` CLI)

- SolutionのZipを `pac solution unpack` でソースファイル群に分解し、編集後 `pac solution pack` で再Zip化、`pac solution import` で環境に反映する
- Microsoft公式のALM(Application Lifecycle Management)手法
- **未検証・これから試す**

### 仕組みメモ

- `customizations.xml`(全コンポーネントが1本の巨大XML)を、コンポーネント単位のフォルダ/ファイルに分割する変換処理が核
- Flow(Power Automate)は `Workflows/` 配下にJSON(clientdata)として格納される → 理論上は直接編集可能
- Canvas Appは `.msapp`(実体はZIP)。`--processCanvasApps` を付けるとさらに展開され `.pa.yaml` 相当のソースになり、Canvas Apps MCPの世界と繋がる
- `pac solution import` は最終的にUIウィザードと同じDataverseの `ImportSolution` APIを叩くため、機械的な結果はUIインポートと同一

### UIインポートとの既知の差分(検証前の仮説)

1. CLI importはデフォルトで**自動publishされない**(`--publish-changes` が必要)
2. **接続参照・環境変数の値**はUIのように対話的に聞かれない。`--settings-file` で明示的に渡す必要あり
3. Canvas Appは `--processCanvasApps` なしだとバイナリのまま展開されない
4. unpack→pack往復で **XMLの整形ノイズ差分** が出ることがある

### 失敗パターンの整理(検証前の仮説)

- **技術的に即失敗するケース**(安全側): 手動Zip化(pac solution packを使わない)、XMLスキーマ違反、依存コンポーネント欠落 → Dataverseのインポートはトランザクションなので失敗時はロールバックされ、環境は壊れない
- **インポートは成功するが中身が壊れているケース**(危険): Canvas Appの `.msapp` 再構築が不完全、Flow内JSONの参照整合性が崩れている、など。動かして初めて気づく

### ライセンス/課金への影響

- unpack/pack/importという**手段の違いで課金層は変わらない**
- 課金を決めるのはSolutionの中身(プレミアムコネクタ使用有無、Dataverse環境の種類、AI Builder等)
- 唯一気にすべきは、importの繰り返しがDataverseのAPIリクエスト数上限にカウントされる点(試行錯誤を繰り返す研究スタイルでは要注意)

---

## 比較表

| | Canvas Apps MCP | Solution unpack/pack |
|---|---|---|
| 対象範囲 | Canvas Appのみ | Solution全体(テーブル・Flow・Canvas App・接続等) |
| 検証状況 | 使用済み | 未検証 |
| 所感 | 質は良いが生成が遅い | (これから検証) |
| Flow編集 | 不可 | JSON直接編集で理論上可能 |
| 体験 | 対話的・UIに近い | ソースコード編集寄り、ALM/CI/CD向き |

## 次のアクション

- [ ] `pac auth create` で検証用環境に接続
- [ ] サンプルSolutionを作成 → export → unpack → 中身確認
- [ ] 小さい編集 → pack → import を試し、成功/失敗パターンを実地検証
- [ ] Canvas Apps MCPとSolution unpack/packの生成速度・編集しやすさを定量的に比較
- [ ] PCF(標準コントロールでは足りない場合の独自コントロール開発)は別テーマとして扱う
