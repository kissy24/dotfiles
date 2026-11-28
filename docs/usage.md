# 日常の使い方

[導入と復元](../README.md) · [保守手順](maintenance.md)

## パッケージの更新

`pkgupd` は端末に入っているHomebrewパッケージ全体を調べます。自動更新は、公開から7日経過し、日時とSHA256を検証できる一部の公式caskが対象です。このリポジトリのBrewfileはすべてformulaなので、NeovimやBunなどは候補として表示されても自動更新されません。保留された更新は配布元の公開情報と変更内容を確認して個別に適用してください。

Ubuntu/Debianで引数なしの `pkgupd` を実行すると、システム全体に `sudo apt-get upgrade -y` と `sudo apt-get autoremove -y` が適用され、不要と判定された依存パッケージが削除されます。Homebrew側で失敗した場合もAPTの処理を試みます。どちらのモードでもHomebrewの処理が最後まで進むと `brew cleanup` を実行します。

| 実行する処理 | コマンド |
| --- | --- |
| Homebrewのみ（macOS・Linux共通） | `pkgupd --homebrew-only` |
| Homebrewと、LinuxではAPTの更新・整理 | `pkgupd` |

日時不明による保留は標準エラーに対象と理由が表示され、正常終了します。更新処理自体が失敗した場合は非ゼロで終了します。

## Zsh

プロンプトの1行目にはディレクトリ、Gitブランチ、日本時間を表示します。未追跡・変更・ステージ済みファイルがあればブランチ名に `*` が付きます。直前のコマンドに0.5秒以上かかると実行時間も表示されます。2行目の `❯` は成功時に緑、失敗時に赤になります。

| キー | 操作 |
| --- | --- |
| `Ctrl-R` | 履歴を検索 |
| `Ctrl-T` | ファイルを選択 |
| `Alt-C` | ディレクトリを選択して移動 |

マシン固有のエイリアス、環境変数、PATHは `~/.zshrc.local` に書きます。管理対象の `.zshrc` が最後に読み込み、セットアップやアンインストール後も残ります。Rustを利用する端末では、必要に応じて `[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"` を追加してください。

補完が使えなくなった場合は `autoload -Uz compaudit; compaudit` で所有者や書き込み権限を確認してください。uvやHerdrを更新して補完が古くなった場合は、checkoutで `./setup.sh` を再実行するとキャッシュを再生成できます。

## Herdr

WezTermを起動すると、Herdrが利用可能な場合はバックグラウンドセッションを新規作成または再接続します。Herdrが未導入の場合や、更新後のクライアントと常駐中の旧サーバーのバージョン不整合などでHerdrが異常終了した場合は、WezTermを閉じずに通常のZshを開きます。ほかの端末からは、作業ディレクトリで`herdr`または短縮エイリアスの`hr`を実行して接続できます。設定は`Ctrl-b`プレフィックス、端末のカラーパレット、マウス操作、新しいペインへのカレントディレクトリ継承を使用します。

Herdr更新後に旧サーバーとの不整合が表示された場合は、セッション内の作業を保存してから`hrr`を実行します。確認に同意すると既定のHerdrセッションとその配下の全プロセスを停止し、新しいバージョンで再接続します。名前付きセッションは`hrr セッション名`で指定できます。

Windows版WezTermではウィンドウをマウスで移動できるようにネイティブタイトルバーを表示します。macOSとLinuxではタイトルバーを非表示にします。

Herdrのタブバーは常に表示され、クリックで切り替えられます。1つのプロジェクトを1つのWorkspaceとして扱い、その中の表示や用途をタブで分けます。新しいタブは名前の入力を求めず即座に作成します。macOSでは`Cmd-t`でタブ、`Cmd-Shift-t`でWorkspaceを作成し、`Cmd-w`、`Cmd-Shift-[`／`Cmd-Shift-]`、`Cmd-1`〜`Cmd-9`も使用できます。WindowsおよびLinuxでは`Ctrl-Shift-t`でタブ、`Ctrl-Shift-n`でWorkspaceを作成し、`Ctrl-Shift-w`と`Ctrl-Tab`／`Ctrl-Shift-Tab`も使用できます。これらはWezTermがHerdrのキー操作へ変換し、従来の`Ctrl-b`操作も引き続き利用できます。

作業ディレクトリと同名のWorkspaceを直接作成する場合は、Zsh関数の`hrw`を使用します。引数を省略するとカレントディレクトリを使い、任意でディレクトリと表示名を指定できます。

```sh
hrw
hrw ~/Projects/dotfiles
hrw ~/Projects/dotfiles docs
```

主な操作は次のとおりです。

| 操作 | キー |
| --- | --- |
| デタッチ | `Ctrl-b q` |
| 新しいWorkspace | `Ctrl-b Shift-n` |
| 新しいタブ | `Ctrl-b c` |
| 左右に分割 | `Ctrl-b v` |
| 上下に分割 | `Ctrl-b -` |
| ペイン移動 | `Ctrl-b h/j/k/l` |
| リサイズモード | `Ctrl-b r` |
| ワークスペース一覧 | `Ctrl-b w` |
| サイドバー表示切替 | `Ctrl-b b` |
| 設定再読み込み | `Ctrl-b Shift-r` |

Herdr内でCodex CLIを使っているときは、次のキーで作業中のペインにポップアップを開けます。キーは順に押します。

| キー | 用途 | Codexに戻る操作 |
| --- | --- | --- |
| `Ctrl-b` → `Ctrl-g` | lazygitで作業ツリーの差分を確認 | メイン画面で `q` |
| `Ctrl-b` → `Ctrl-e` | NeovimのOilでファイルを選ぶ | `:qa`（編集を保存する場合は `:wqa`） |

対象のリポジトリやworktreeに移動してから `codex` を起動すると、Herdrがペインから取得した作業ディレクトリでツールが開きます。設定更新後は `Ctrl-b` → `Shift-r` で反映できます。

Codexのセッション識別とHerdr再起動後のネイティブ復元を有効にする場合は、`herdr integration install codex`を一度実行します。この操作は`~/.codex`のhook設定を更新するため、共通セットアップからは自動実行しません。

## Neovimの検索（Telescope）

ノーマルモードで`Space` → `f` → 次のキーを順に押します。まず`Space f f`でファイル名を入力し、矢印キーで候補を選んで`Enter`で開けます。

| キー | 操作 |
| --- | --- |
| `Space f f` | ファイル名をあいまい検索 |
| `Space f g` | ファイル内の文字列を検索 |
| `Space f b` | 開いているバッファを最近使った順で表示 |
| `Space f h` | Neovimヘルプを検索 |
| `Space f k` | 説明付きのキー操作一覧を検索 |
| `Space f r` | 前回の検索を再開 |

検索画面では `Ctrl-N`／`Ctrl-P` で候補を移動し、`Enter` で開き、`Esc` で中止します。`Ctrl-X`／`Ctrl-V` で上下／左右に分割して開けます。`F1` はヘルプ、`F4` はプレビューの切り替えです。プレビューは1 MiBまでで、画面幅が100桁未満なら省略します。

ファイル・本文検索の起点は `:pwd` に表示されるディレクトリです。`:cd パス` で変更できます。隠しファイルを含み、Gitの除外設定を尊重し、`.git` を除外します。シンボリックリンクはたどりません。本文検索は入力どおりの文字列を使い、大文字を含むときだけ大文字・小文字を区別します。開いているバッファは除外設定にかかわらず一覧に出ます。

## Neovimでの編集

| 操作 | キー |
| --- | --- |
| Oilのファイル一覧を開閉 | `Space j` |
| Oilで選択／プレビュー／閉じる | `Enter`／`Ctrl-P`／`q` または `Esc` |
| 挿入モードで補完を開始・選択 | `Ctrl-Space`、`Ctrl-N`／`Ctrl-P` |
| 選択した候補を確定／補完を中止 | `Ctrl-Y` または `Enter`／`Ctrl-E` |
| パスを補完／スニペット内を移動 | `Ctrl-X Ctrl-F`／`Tab`・`Shift-Tab` |
| LSPで整形 | `Space c f` |
| 現在行のGit履歴表示を切り替え | `:Gitsigns toggle_current_line_blame` |

補完候補の未選択時は `Enter` で改行します。コマンドラインと検索の候補は `Tab`／`Shift-Tab` で選びます。LSPの進捗はステータスラインに表示します。セットアップでLua、Markdown、Go、HTML、CSS、JSON、Python用のLanguage Serverを導入します。JavaScript・TypeScriptの `ts_ls` は自動起動しません。

Markdownは現在行だけ原文を表示し、周囲では見出し、表、チェック欄を描画します。`:RenderMarkdown toggle` で装飾を切り替えられます。checkoutで `nvim tests/fixtures/markdown.md` を開くと[表示用サンプル](../tests/fixtures/markdown.md)を確認できます。
