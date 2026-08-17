# powerplatform-lab — 作業メモ / ハマりどころ

Power PlatformをAI(Claude)で開発する研究用リポジトリ。詳しい調査ログは
[docs/findings.md](docs/findings.md) を参照。ここには**同じミスを繰り返さないための注意点**だけを書く。

## pac CLI

- このマシンでは `pac` という名前が過去にnpmの無関係なパッケージと衝突していた(削除済み)。
  もし再び `pac: command not found` や意味不明なエラーが出たら、まずフルパスで実行して切り分けること:
  `"C:\Users\<user>\AppData\Local\Microsoft\PowerAppsCLI\pac.cmd"`
- bashのシェルではこのフルパス実行が確実。`pac` だけだと拡張子解決が効かないことがある。
- テナントに複数環境がある場合、`pac auth create` 直後は既定(default)環境に接続されるだけ。
  目的の環境(例: 開発者環境)に切り替えるには `pac org list` で一覧を見てから
  `pac org select --environment <URL>` を必ず実行すること。忘れると `pac solution list` 等で
  目的のSolutionが見えず「存在しない」と誤解する。
- 社内テナントのAAD側で `pac auth create` の埋め込みブラウザが「サポートされていないブラウザ」
  と判定されることがある。その場合は `pac auth create --deviceCode` を使う。

## Canvas Apps MCP (canvas-authoring)

- `connect` は対象アプリで **Coauthoring(共同編集)が有効**になっていないと失敗する
  (Studio → ファイル → 設定 → 今後の機能 → Coauthoring をオンにして保存)。
- `connect` 成功後も、**Studioで実際にそのアプリを開いていない**と `compile_canvas` が
  「アクティブなcoauthoringセッションが検出できない」と警告し、変更が反映されない。
  MCP経由の編集を反映させたい時は、必ずユーザーにStudioでアプリを開いた状態にしてもらうこと。
- Studio編集中でも `pac solution export` は問題なく実行できる(export APIとクライアント
  編集セッションは独立)。

## Canvas App YAML(.pa.yaml)を書くとき

プロパティ名・アイコン名・レイアウトで実際に踏んだ罠は
[docs/canvas-app-yaml-notes.md](docs/canvas-app-yaml-notes.md) にまとめてある。
`.pa.yaml` を書く/直す前に必ず目を通すこと(要点: プロパティ名は`describe_control`で
必ず確認する、アイコン名は181種類の限定セット外だと丸表示になりエラーにならない、
`ManualLayout`の絶対座標は画面幅とズレるとはみ出す、`DataTable`よりGalleryを使う)。
より体系的なルール集(配色・命名規則・AutoLayout設計)は同ファイル内で
[kaizen-irai-kanri-app](https://github.com/yasusi-1234/kaizen-irai-kanri-app)の
`SCREEN_RENDERING_RULES_GENERIC.md` にリンクしている。

## Playwright + canvas-authoring MCPによるループエンジニアリング

Studioを開いた状態のブラウザをPlaywright MCPで操作すれば、canvas-authoring MCPでの
YAML編集と組み合わせて「編集→保存→公開→再生モードでプレビュー→スクリーンショットで
レビュー→修正」のループを**Claudeが手動確認なしで自動的に**回せる(2026-08-16に
TestApp2で実証済み)。

- 保存ボタン: Studio内`#commandBar_save`(「上書き保存 (Ctrl+S)」)
- 公開ボタン: テキスト「公開」。クリックすると公開ダイアログが開き、
  `getByTestId('appDescriptionTextField')`の説明欄がバージョンメモに相当する
  (ここに変更内容を書いて公開すれば、Power Apps側のバージョン履歴に残る)
- 再生モード: 「アプリのプレビュー (F5)」メニュー項目
- **このループの実行回数は1タスクにつき最大5回まで**とする(無限ループ防止のため、
  ユーザー指示で明文化)。5回に達したら未解決の課題が残っていてもそこで打ち切り、
  最後に変更内容のサマリをユーザーに報告する。
- 「公開」の自動確定可否はユーザーに一度確認を取ってから進める(2026-08-16時点では
  開発中テストアプリに対して「毎回自動で公開してよい」との回答を得ている。バージョン
  履歴で簡単にロールバックできるため)。

## Solution unpack の既知の問題

- `pac solution unpack --processCanvasApps` はドキュメント上も **プレビュー機能**。
  Canvas Appを含むSolutionをunpackすると `PA3011: Roundtrip validation on unpack failed`
  (`AnalysisOptions.DataflowAnalysisEnabled` 等のプロパティ差分が原因)というエラーに
  遭遇することがある。ファイル自体は正常に書き出される(exit code 0)ので実害はなさそうだが、
  本格的な編集フローとしてはまだ過信しないこと。詳細は [docs/findings.md](docs/findings.md) 参照。
