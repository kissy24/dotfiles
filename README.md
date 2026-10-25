# Dotfiles

[![License: MIT](https://img.shields.io/github/license/kissy24/dotfiles)](LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/kissy24/dotfiles)

macOSおよびUbuntu/WSL向けの個人開発環境です。共通のコマンドラインツールはHomebrewでインストールし、セットアップ時にコミット済み設定のスナップショットを作り、`$HOME`以下から参照します。作業コピーの編集・ブランチ切替は利用中の設定に反映されません。

## 必要な環境

- macOS、または`apt-get`を利用できるUbuntu/Debian環境
- ZshとWezTerm
- `HackGen Console NF`
- macOSではHomebrew

Ubuntuでは、セットアップスクリプトがaptの前提パッケージとHomebrewをインストールします。Zsh、WezTerm、フォントは別途インストールしてください。

## インストール

開発環境一式をインストールします。

```sh
git clone https://github.com/kissy24/dotfiles.git
cd dotfiles
./setup.sh
```

既存の無関係なdotfilesはデフォルトでは変更せずにスキップします。以前このcheckoutが作った直接リンクは、バックアップしてスナップショットへのリンクへ移行します。管理対象のシンボリックリンクへ置き換える場合は`./setup.sh --force`を使います。置換対象は削除せず、同じ親ディレクトリの`<元の名前>.backup-<日時>.<ランダム文字列>/original`へ退避します。既に正しいリンクになっている場合はバックアップを作りません。バックアップはアンインストール後も残ります。

元の設定へ戻す場合は、`./uninstall.sh`で管理対象のリンクを解除してから、表示された退避先の`original`を元のパスへ移動してください。復元先にファイルやディレクトリが残っている場合は、内容を確認して別の場所へ退避してから戻します。複数のバックアップがある場合は復元したいものを選びます。Windows側の`.wslconfig`も同じ方式で退避します。

パッケージの宣言は`Brewfile`、`packages/apt.txt`、`packages/bun-lsp/package.json`にあります。SheldonとMasonの依存関係は、それぞれの設定ファイルで管理します。HomebrewインストーラーのSHA・SHA256とpre-commit本体の版は`packages/bootstrap.json`で管理します。

## 設定の反映とレビュー

設定は`${XDG_DATA_HOME:-~/.local/share}/dotfiles/releases/`へ`git archive HEAD`で取り出し、`current`リンクを切り替えて反映します。未追跡ファイル・認証情報はコピーせず、管理対象に未コミットの変更がある場合や、追跡対象のシンボリックリンクがある場合は拒否します。過去のスナップショットは復旧用に残します。

設定だけを反映する場合は、差分をレビューしてコミットした後に実行します。

```sh
./scripts/deploy-config.sh
```

依存関係やLSPの版も変えた場合は`./setup.sh`を実行します。初回の移行後は、`git pull`やcheckoutだけでは日常環境の設定は変わりません。レビュー・開発には別worktreeを使ってください。

```sh
git fetch origin
git worktree add -b review/example ../dotfiles-review origin/main
```

未信頼PRのスクリプトやNeovim設定を実行して確かめる場合は、認証情報を持たない使い捨てVM・CI runnerを使います。worktreeだけでは実行したコードを隔離できません。特に初回移行前は、利用中の設定を指すcheckoutで未信頼PRへ切り替えないでください。

## 導入する環境

- Zsh向けのStarship、Sheldon、zoxide、fzf連携
- Herdrによる永続セッション、ワークスペース、タブ、ペイン、AIエージェント状態の管理
- Lazy.nvim、Tree-sitter、補完、Telescope、Oil、Git連携、LSP、Markdownレンダリングを備えた安定版Neovim
- Bunに統一したJavaScript/TypeScript環境（Node.jsとnpmはインストールしません）
- goplsを含むGo開発環境
- uvによるpre-commitとPythonツール管理

fzfのZsh連携では、Ctrl-Rによる履歴検索、Ctrl-Tによるファイル選択、Alt-Cによるディレクトリ選択、曖昧補完を利用できます。

Zshの起動時間を抑えるため、セットアップ時にuvとHerdrの補完を`${XDG_CACHE_HOME:-~/.cache}/dotfiles/zsh/`へ生成し、`compinit`のdumpも更新します。CLIを個別に更新して補完内容が変わった場合は、`./setup.sh`を再実行するとキャッシュを更新できます。

補完の初期化では、キャッシュがある場合も毎回ディレクトリの所有者と権限を検査します。安全でない補完は`compinit -i`で除外します。補完が使えなくなった場合は、`autoload -Uz compaudit; compaudit`で対象を確認し、所有者や他ユーザーの書き込み権限を見直してください。

Ubuntu/WSLではUbuntu標準の`compinit`を無効化し、管理対象の`.zshrc`によるキャッシュ付き初期化だけを実行します。また、Windows版WezTermを端末として使う構成ではWSLgが不要なため、`setup.sh`はWindowsユーザーディレクトリへ`.wslconfig`をコピーしてLinux GUI VMの自動起動を無効化します。既存の`.wslconfig`はデフォルトでは変更せず、`--force`指定時だけバックアップして置き換えます。

WSL設定を反映するには、セットアップ後にPowerShellでWSLを停止してからWezTermを開き直します。

```powershell
wsl.exe --shutdown
```

この設定ではWSL内のLinux GUIアプリを利用できません。必要な場合はWindowsの`%UserProfile%\.wslconfig`から`guiApplications=false`を削除し、再度`wsl.exe --shutdown`を実行してください。

`uninstall.sh`は、Windows側の`.wslconfig`がリポジトリの管理版と完全に一致する場合だけ削除します。利用者が追記・変更した設定は残します。

## 管理する設定

`setup.sh`はUbuntuでZshを導入し、`.zshrc`、Herdr、Starship、Neovim、WezTerm、Sheldon、Lazygit、GitHub CLIの設定へシンボリックリンクを作成します。Herdrはログも`~/.config/herdr/`へ保存するため、ディレクトリ全体ではなく`config.toml`だけを管理します。GitHub CLIも`~/.config/gh/config.yml`だけを管理し、認証情報の`hosts.yml`などは保持します。

以前のセットアップが作った`~/.config/gh`のディレクトリリンクは、次回セットアップ時に通常のディレクトリへ移行します。中のローカルファイルは権限を保ってコピーし、旧リンクもバックアップします。リポジトリ内に残っているGit管理対象外の`hosts.yml`などは削除しません。別の場所を指す利用者独自のディレクトリリンクは、`--force`でも変更せずスキップします。

NeovimプラグインはGit管理する`.config/nvim/lazy-lock.json`に固定し、セットアップでは`Lazy! restore`で固定版を復元します。Lazy.nvim自体も初回導入時にロックファイルのコミットを取得してから読み込みます。意図的に更新する場合は、隔離した検証環境で`:Lazy update`を実行し、更新した`lazy-lock.json`を作業コピーへ戻して差分と動作を検証し、コミットしてください。日常環境のNeovimから更新したロックファイルは配備済みスナップショット側にあるため、そのままではGitに反映されません。`nvim-treesitter`とHomebrewの`tree-sitter-cli`を使い、Markdown、Python、Go、TypeScript、TSX、Luaのパーサーをセットアップ時にインストールします。Go Modules用の`gomod`、`gosum`、`gowork`も対象です。Markdownを開くと`render-markdown.nvim`が読み込まれ、管理対象の`markdown`と`markdown_inline`パーサーで表示を拡張します。Lua、Markdown、GoのLanguage ServerはMason設定内の`dotfiles_versions`で版を固定し、セットアップ時にインストール済みの版も確認・同期します。Neovim起動だけでLSPをインストールする処理は無効です。TypeScript/JavaScript、HTML、CSS、JSON、PythonのLanguage Serverは追跡対象のBun manifestからインストールしてBunで実行します。

### Herdr

WezTermを起動すると、Herdrが利用可能な場合はバックグラウンドセッションを新規作成または再接続します。Herdrが未導入の場合や、更新後のクライアントと常駐中の旧サーバーのバージョン不整合などでHerdrが異常終了した場合は、WezTermを閉じずに通常のZshを開きます。ほかの端末からは、作業ディレクトリで`herdr`または短縮エイリアスの`hr`を実行して接続できます。設定は`Ctrl-b`プレフィックス、端末のカラーパレット、マウス操作、新しいペインへのカレントディレクトリ継承を使用します。

Herdr更新後に旧サーバーとの不整合が表示された場合は、セッション内の作業を保存してから`hrr`を実行します。確認に同意すると既定のHerdrセッションとその配下の全プロセスを停止し、新しいバージョンで再接続します。名前付きセッションは`hrr セッション名`で指定できます。

Windows版WezTermではウィンドウをマウスで移動できるようにネイティブタイトルバーを表示します。macOSとLinuxではタイトルバーを非表示にします。

Herdrのタブバーは常に表示され、クリックで切り替えられます。1つのプロジェクトを1つのWorkspaceとして扱い、その中の表示や用途をタブで分けます。新しいタブは名前の入力を求めず即座に作成します。macOSでは`Cmd-t`でタブ、`Cmd-Shift-t`でWorkspaceを作成し、`Cmd-w`、`Cmd-Shift-[`／`Cmd-Shift-]`、`Cmd-1`〜`Cmd-9`も使用できます。WindowsおよびLinuxでは`Ctrl-Shift-t`でタブ、`Ctrl-Shift-n`でWorkspaceを作成し、`Ctrl-Shift-w`と`Ctrl-Tab`／`Ctrl-Shift-Tab`も使用できます。これらはWezTermがHerdrのキー操作へ変換し、従来の`Ctrl-b`操作も引き続き利用できます。

作業ディレクトリと同名のWorkspaceを直接作成する場合は、Zsh関数の`hrw`を使用します。引数を省略するとカレントディレクトリを使い、任意でディレクトリと表示名を指定できます。

```sh
hrw
hrw ~/Projects/docfiles
hrw ~/Projects/docfiles docs
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

Codexのセッション識別とHerdr再起動後のネイティブ復元を有効にする場合は、`herdr integration install codex`を一度実行します。この操作は`~/.codex`のhook設定を更新するため、共通セットアップからは自動実行しません。

### Neovimのファイルサイドバー

`Space` → `j`でOilを左端に幅30列のサイドバーとして開閉します。Oil内で`Enter`を押すと、ディレクトリはその場で移動し、ファイルは右隣の編集ウィンドウに開きます。右側に編集ウィンドウがない場合は、新しく右側に分割して開きます。

### NeovimのMarkdown表示

MarkdownはCatppuccinの配色で、見出しを太字と控えめな色、コードを余白付きの背景、表を細い角丸罫線で表示します。チェック済み項目には取り消し線を付け、引用や`> [!NOTE]`などの注意書きも見分けやすくします。

通常・コマンドラインモードでは行番号・空白記号・カーソル行の強調を隠し、本文を折り返します。挿入・選択モードでは元のMarkdownと通常の編集表示へ戻ります。`:RenderMarkdown toggle`で装飾を切り替えられます。元のファイル内容は変更しません。

表示例は`nvim tests/fixtures/markdown.md`で確認できます。装飾は`.config/nvim/lua/plugins/render-markdown.lua`、配色は`catppuccin.lua`で調整します。

### マシン固有のZsh設定

管理対象の`.zshrc`は、`~/.zshrc.local`が存在する場合に最後に読み込みます。特定のマシンだけで使うエイリアス、環境変数、PATHなどを記述できます。

```sh
touch ~/.zshrc.local
chmod 600 ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

`~/.zshrc.local`は、このリポジトリによる作成、リンク、削除、Git管理の対象外です。共通設定の後に読み込むため、共通のエイリアスや環境変数をマシンごとに上書きできます。

Rust/Cargoを別途利用する場合は、必要に応じて`[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"`を`~/.zshrc.local`へ追加してください。

### パッケージ更新

`setup.sh`はHomebrewの既存パッケージを通常アップグレードしません。新規パッケージの導入に必須な依存の変更はHomebrewの判断で発生する場合があります。日常の更新には`pkgupd`を使います。

`pkgupd`はHomebrewの更新候補をローカルで初めて観測してから7日間待ち、同じバージョンが継続しているパッケージだけを更新します。待機中に候補バージョンが変わった場合は、そのバージョンの待機期間を初めから数え直します。観測状態は`${XDG_STATE_HOME:-~/.local/state}/pkgupd/homebrew.tsv`に保存します。

```sh
pkgupd
```

UbuntuではHomebrewのみにクールダウンを適用し、APTのシステム・セキュリティ更新は遅延させず従来どおり適用します。Homebrewの処理に失敗してもAPTの更新を試みます。各パッケージマネージャーは途中で失敗したら後続処理を停止し、最後に両方の終了コードを表示して、いずれかが失敗した場合は`pkgupd`も失敗を返します。Homebrewが対象パッケージのインストールに必要と判断した依存関係は、同時に更新される場合があります。Homebrewだけを処理する場合は`pkgupd --homebrew-only`、待機日数を変更する場合は`PKGUPD_COOLDOWN_DAYS`を使用します。

```sh
PKGUPD_COOLDOWN_DAYS=14 pkgupd
```

## アンインストール

デフォルトでは、このリポジトリが管理するシンボリックリンクだけを削除します。

```sh
./uninstall.sh
```

パッケージも削除する場合は、明示的な指定と確認が必要です。

```sh
./uninstall.sh --packages
```

この操作では、セットアップ前から存在していた場合でも、宣言済みのパッケージを削除します。

## 開発

テストとスモークテストは`tests/`に、セットアップ・保守用スクリプトと共通処理は`scripts/`に配置しています。`scripts/run-nvim-check.sh`はセットアップとテストで共用します。

Neovimの`.config/nvim/lua/plugins/`は、1プラグインの設定を1つのLuaファイルにまとめています。Mason・補完・Fidget・oil-gitも専用ファイルで設定し、プラグイン間の読み込み順は`dependencies`で指定します。追加設定のない補完ソースや共通ライブラリは、利用側の`dependencies`に参照だけを記載します。

GitHub ActionsでUbuntuとmacOSのセットアップスクリプトを検証します。ローカル検査はセットアップ時にuv経由でインストールされます。

```sh
./tests/smoke-test.sh
pre-commit run --all-files
```

GitHub Actionsとpre-commit hookの外部コードはコミットSHAに固定しています。検証CIの`GITHUB_TOKEN`は`contents: read`に制限し、checkout後のGit認証情報も保存しません。観測記録を更新するmain専用ジョブだけが`contents: write`を持ちます。

pre-commitではBetterleaksがステージ済みの変更を走査し、token、APIキー、秘密鍵などの機微情報を検出するとコミットを拒否します。検出結果に機微情報そのものを出力しないよう、redactを有効にしています。CIではpre-commitの回避を考慮し、追跡対象の作業ツリー全体を再走査します。加えて`Scan Secret History`はPR・mainへのPush・週次実行で全履歴を取得し、`betterleaks-history`でPR途中のコミットを含む到達可能な履歴全体を走査します。後続コミットで削除された秘密も対象です。ローカルでは`pre-commit run betterleaks-history --hook-stage manual --all-files`を使います。

スモークテストでは、各CLIの起動、ripgrepとfzfによる検索、隔離したHerdrサーバーの起動・接続・停止、zoxideのデータベース操作、`pkgupd`の候補バージョンと待機期間の判定、Bun・Go・Pythonのコード実行、管理対象の全Tree-sitterパーサー、ヘッドレスNeovim上でのTypeScript Language Server接続、Markdownパーサーと`render-markdown.nvim`の初期化を確認します。Neovimの検証とセットアップ用Luaコード内の例外・assert失敗は、非ゼロの終了コードで通知します。意図的な失敗による終了コードの回帰テストと、隔離した一時ディレクトリ上でのバックアップ・GitHub CLI移行・アンインストールのテストも実行します。補完キャッシュ作成後の権限変更、Homebrew／APTそれぞれの失敗、スナップショットの分離、削除済み秘密の履歴検出、初回観測時刻の境界・欠損・未来日時・過去日付コミットの拒否、Neovimのインストール済みコミットとロックファイルの一致も検証します。Herdrの対話UI、GUI表示、GitHub認証は手動確認の対象です。

依存関係のEOL検査は毎週月曜日と関連ファイルを変更するPull Requestで実行します。Homebrew formulaの`deprecated`・`disabled`、Neovim・Sheldon・pre-commit・GitHub Actionsで利用するGitHubリポジトリの`archived`・`disabled`を検出すると失敗します。ローカルでも次のコマンドで実行できます。

```sh
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-eol.sh
```

更新頻度の低さだけではEOLと判定せず、HomebrewとGitHubが提供する明示的なライフサイクル情報だけを失敗条件にします。

Git依存の7日間待機は、コミット作者が指定できる日時を使用しません。`Observe Dependency Versions`がmainと公開中PRの宣言を**データとしてのみ**読み、GitHubのサーバー時刻で初回観測を記録します。PRコードのcheckout・import・実行や依存のインストールは行いません。mainへのPush、6時間ごとの定期実行、mainからの手動実行が対象です。

記録は同じリポジトリの`chore/dependency-observations`ブランチに保存します。PRの検査はこの信頼されたブランチを読み、PR内の記録ファイルやキャッシュは信頼しません。検証ジョブには書き込み権限を与えません。観測記録の欠損、未観測のSHA、7日未満・未来の時刻は失敗になります。別リポジトリの同じSHAも別の依存として扱います。待機期間を環境変数で短縮する機能はありません。

初回移行時だけ、承認済みのmainに既に固定されているSHAを基準として登録します。新しく固定・追加するSHAは例外に含めません。管理者がレビューしたコードから、書き込み権限を持つtokenで一度だけ初期化します。再初期化による承認済み基準の拡張は拒否します。

```sh
GITHUB_TOKEN="$(gh auth token)" python3 scripts/dependency_observations.py initialize
```

新しい版を含むPRは、観測後7日間CIが失敗するのが正常です。初回観測後に同じSHAを維持したまま7日経過したらCIを再実行してください。移行PRで追加したobserverはmainへマージされるまで自動実行されないため、その間は管理者がレビュー済みコードから`observe`を実行します。観測ブランチの削除・改変は検査の信頼性に影響するため、管理者とmainのobserver以外に書き込み権限を与えないでください。

```sh
GITHUB_TOKEN="$(gh auth token)" python3 scripts/dependency_observations.py observe
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-cooldown.sh
```

Git待機の対象はGitHub Actions、pre-commit hook、Neovim、Sheldon、Homebrewインストーラーの固定SHAです。Bunのnpm依存は引き続きレジストリ側の公開日時を使います。Homebrew formula自体はローリング配布のままで、更新時の待機は`pkgupd`が担当します。pre-commit本体とMasonのLSPは版固定ですが、Gitの初回観測チェックの対象ではありません。版固定は既知の安全性や上流の配布物の不変性を保証するものではありません。

## ライセンス

[MIT](LICENSE)
