# Dotfiles

[![License: MIT](https://img.shields.io/github/license/kissy24/dotfiles)](LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/kissy24/dotfiles)

macOSおよびUbuntu/WSL向けの個人開発環境です。共通のコマンドラインツールはHomebrewでインストールし、`$HOME`以下からこのcheckoutの設定へシンボリックリンクを作成します。設定の編集や`git pull`は、各アプリが設定を読み込む際に反映されます。

## 必要な環境

- macOS、または`apt-get`を利用できるUbuntu/Debian環境
- ZshとWezTerm
- `HackGen Console NF`
- macOSではHomebrew
- GitとPython 3.9以上（導入前の公開日時検査に使用）

Ubuntuでは、セットアップスクリプトがaptの前提パッケージとHomebrewをインストールします。Zsh、WezTerm、フォントは別途インストールしてください。

## インストール

開発環境一式をインストールします。

```sh
git clone https://github.com/kissy24/dotfiles.git
cd dotfiles
./setup.sh
```

既存の無関係なdotfilesはデフォルトでは変更せずにスキップします。以前のスナップショットを指す既知の管理対象リンクは、バックアップしてcheckoutへの直接リンクに戻します。管理対象のシンボリックリンクへ置き換える場合は`./setup.sh --force`を使います。置換対象は削除せず、同じ親ディレクトリの`<元の名前>.backup-<日時>.<ランダム文字列>/original`へ退避します。既に正しいリンクになっている場合はバックアップを作りません。バックアップはアンインストール後も残ります。

元の設定へ戻す場合は、`./uninstall.sh`で管理対象のリンクを解除してから、表示された退避先の`original`を元のパスへ移動してください。復元先にファイルやディレクトリが残っている場合は、内容を確認して別の場所へ退避してから戻します。複数のバックアップがある場合は復元したいものを選びます。Windows側の`.wslconfig`も同じ方式で退避します。

パッケージの宣言は`Brewfile`、`packages/apt.txt`、`packages/bun-lsp/package.json`にあります。Sheldonの依存はプラグイン設定、ネイティブLSPは `packages/native-lsp.json` と `packages/homebrew-bottles.json` で管理します。HomebrewインストーラーのSHA・SHA256とpre-commit本体の版は`packages/bootstrap.json`で管理します。

## 設定の反映とレビュー

設定はcheckoutを直接参照します。リンク作成後は、設定の編集や`git pull`のたびに配備操作を行う必要はありません。起動中のアプリへの反映には、そのアプリの再読み込みや再起動が必要な場合があります。

リンクを初めて作る場合、管理対象が増えた場合、または以前のスナップショット方式から戻す場合は、次を実行します。パッケージのインストールやHerdrの停止は行いません。

```sh
./scripts/deploy-config.sh
```

`${XDG_DATA_HOME:-~/.local/share}/dotfiles/current/`を指す既知の管理対象リンクは、`--force`なしでcheckoutへのリンクに戻します。既存のスナップショットとバックアップは削除しません。独自のリンクや通常ファイルはデフォルトで保持します。`pkgupd`のPython補助ファイルも同じcheckoutを参照します。

依存関係やLSPの版も変えた場合は`./setup.sh`を実行します。利用中のcheckoutの編集・ブランチ切替は日常環境にも影響するため、ここは信頼済みのmainに保ち、レビュー・開発には別worktreeを使ってください。

```sh
git fetch origin
git worktree add -b review/example ../dotfiles-review origin/main
```

未信頼PRのスクリプトやNeovim設定を実行して確かめる場合は、認証情報を持たない使い捨てVM・CI runnerを使います。worktreeだけでは実行したコードを隔離できません。利用中の設定を指すcheckoutで未信頼PRへ切り替えないでください。

## 導入する環境

- Zsh向けのStarship、Sheldon、zoxide、fzf連携
- Herdrによる永続セッション、ワークスペース、タブ、ペイン、AIエージェント状態の管理
- Lazy.nvim、補完、Telescope、Oil、Git連携、LSP、Markdownレンダリングを備えた安定版Neovim
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

以前の`~/.config`全体がcheckoutの`.config`を指す構成は、そのまま保持します。親リンクを実ディレクトリへ変換したり、その配下をコピー・置換したりしません。**Herdrを起動したまま設定リンクを更新できます。** ソケット・ログ・セッションの保存先は変わらず、サービスの停止やソケットの削除は行いません。Herdr本体のバージョン更新後に必要な再起動は、下記のHerdr節を参照してください。

親ディレクトリがリンクであるパスは、`--force`でも配下を書き換えずスキップします。利用者独自の親リンクも同様です。アンインストールも親リンク経由の削除をスキップし、`~/.config`全体のリンクは残します。新規環境では`~/.config`を通常のディレクトリとし、管理対象の設定ごとにcheckoutへのリンクを作ります。

以前のセットアップが作った`~/.config/gh`のディレクトリリンクは、次回セットアップ時に通常のディレクトリへ移行します。中のローカルファイルは権限を保ってコピーし、旧リンクもバックアップします。リポジトリ内に残っているGit管理対象外の`hosts.yml`などは削除しません。別の場所を指す利用者独自のディレクトリリンクは、`--force`でも変更せずスキップします。

NeovimプラグインはGit管理する`.config/nvim/lazy-lock.json`に固定し、セットアップでは`Lazy! restore`で固定版を復元します。Lazy.nvim自体も初回導入時にロックファイルのコミットを取得してから読み込みます。意図的に更新する場合は、隔離した検証環境で`:Lazy update`を実行し、更新した`lazy-lock.json`を作業コピーへ戻して差分と動作を検証し、コミットしてください。日常環境のNeovimでロックファイルを更新するとcheckoutも直接変更されるため、依存関係の公開後待機を含む検証は隔離環境で先に行ってください。Markdown表示には`render-markdown.nvim`とNeovim同梱の`markdown`・`markdown_inline`パーサーを使います。Lua、Markdown、GoのLanguage Serverはセットアップ時に検証済みの配布物から `dotfiles-lsp/native` へ導入します。Neovimはこのディレクトリの実行ファイルを使います。Neovim起動だけでLSPをインストールする処理は無効です。HTML、CSS、JSON、PythonのLanguage Serverは追跡対象のBun manifestからインストールしてBunで実行します。 Bunで動かすLSPの作業ディレクトリは管理下の `dotfiles-lsp` に固定し、編集対象はLSPのワークスペースとして渡します。

JavaScript・TypeScriptの編集に `ts_ls` は使用しません。Masonにインストール済みでも自動起動の対象外です。Bun依存を更新する際は`packages/bun-lsp/`で`bun update --minimum-release-age 604800 --lockfile-only --ignore-scripts`を実行し、公開から7日経過した候補だけを採用します。更新後は依存関係のクールダウン検査とスモークテストで、Bun上の全LSPの初期化、およびPythonの型診断を確認します。

### Herdr

WezTermを起動すると、Herdrが利用可能な場合はバックグラウンドセッションを新規作成または再接続します。Herdrが未導入の場合や、更新後のクライアントと常駐中の旧サーバーのバージョン不整合などでHerdrが異常終了した場合は、WezTermを閉じずに通常のZshを開きます。ほかの端末からは、作業ディレクトリで`herdr`または短縮エイリアスの`hr`を実行して接続できます。設定は`Ctrl-b`プレフィックス、端末のカラーパレット、マウス操作、新しいペインへのカレントディレクトリ継承を使用します。

Herdr更新後に旧サーバーとの不整合が表示された場合は、セッション内の作業を保存してから`hrr`を実行します。確認に同意すると既定のHerdrセッションとその配下の全プロセスを停止し、新しいバージョンで再接続します。名前付きセッションは`hrr セッション名`で指定できます。

Windows版WezTermではウィンドウをマウスで移動できるようにネイティブタイトルバーを表示します。macOSとLinuxではタイトルバーを非表示にします。

HerdrのタブバーはWorkspace内のタブが1枚のときは非表示です。2枚以上になると表示され、クリックでタブを切り替えられます。1つのプロジェクトを1つのWorkspaceとして扱い、その中の表示や用途をタブで分けます。新しいタブは名前の入力を求めず即座に作成します。macOSでは`Cmd-t`でタブ、`Cmd-Shift-t`でWorkspaceを作成し、`Cmd-w`、`Cmd-Shift-[`／`Cmd-Shift-]`、`Cmd-1`〜`Cmd-9`も使用できます。WindowsおよびLinuxでは`Ctrl-Shift-t`でタブ、`Ctrl-Shift-n`でWorkspaceを作成し、`Ctrl-Shift-w`と`Ctrl-Tab`／`Ctrl-Shift-Tab`も使用できます。これらはWezTermがHerdrのキー操作へ変換し、従来の`Ctrl-b`操作も引き続き利用できます。

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

### Neovimの検索（Telescope）

ノーマルモードで`Space` → `f` → 次のキーを順に押します。まず`Space f f`でファイル名を入力し、矢印キーで候補を選んで`Enter`で開けます。

| キー | 操作 |
| --- | --- |
| `Space f f` | ファイル名をあいまい検索 |
| `Space f g` | ファイル内の文字列を検索 |
| `Space f b` | 開いているバッファを最近使った順で表示 |
| `Space f h` | Neovimヘルプを検索 |
| `Space f k` | 説明付きのキー操作一覧を検索 |
| `Space f r` | 前回の検索を再開 |

旧`ff`・`fg`・`fb`・`fn`の割り当ては廃止し、Neovim標準の`f{文字}`による行内移動に戻しました。LSPの手動整形は`Space f`から**`Space c f`**へ変更し、検索キーとの競合を解消しています。

検索画面は入力欄が上で、候補も上から並びます。`↑`／`↓`または`Ctrl-P`／`Ctrl-N`で移動、`Enter`で開き、`Esc`一回で中止します。`F1`は操作ヘルプの表示切替、`F4`はプレビューの表示切替、`Ctrl-U`／`Ctrl-D`はプレビューのスクロールです。`Ctrl-X`／`Ctrl-V`で上下／左右に分割して開けます。画面幅が100桁未満の場合はプレビューを自動で省略します。

ファイル・本文検索は現在のディレクトリ（`:pwd`）以下を対象にし、そのパスを入力欄のタイトルへ表示します。プロジェクトのルートで`nvim`を起動するか、`:cd パス`で対象を切り替えてください。開いたバッファ・ヘルプ・キー一覧はこのディレクトリ制限の対象外です。

本文検索は正規表現ではなく、入力した文字列をそのまま検索します。たとえば`foo.bar`の`.`も文字として扱います。小文字だけなら大文字・小文字を区別せず、大文字を含めると区別します。隠しファイルも対象ですが、Gitの除外設定を尊重し、`.git`を除外してシンボリックリンクをたどりません。ripgrepの外部設定によって検索範囲が変わらないようにしています。秘密情報の自動判別は行わないため、`.env`等はプロジェクトの`.gitignore`で管理してください。開いているバッファの一覧には除外対象も表示されます。

プレビューは1 MiBまでに制限します。特殊文字を含むパスを外部コマンドへ渡さないため、外部`file`コマンドによるMIME判定は使用しません。バイナリ表示の自動判別は保証せず、画像ビューア等も追加しません。Telescope・Plenaryの固定SHAと既存のripgrepを利用し、追加プラグイン・CLI・ビルド処理はありません。

### Neovimの標準補完・LSP進捗・Git履歴

Neovim 0.12以上を使用します。補完はプラグインを使わず、標準の自動補完と`vim.lsp.completion`で行います。挿入モードでは現在のバッファの単語とLSPの候補を表示し、`Ctrl-Space`でも補完を開始できます。`Ctrl-N`／`Ctrl-P`で選択、`Ctrl-Y`または選択後の`Enter`で確定、`Ctrl-E`で中止します。未選択の`Enter`は改行します。パス補完は`Ctrl-X Ctrl-F`、LSPのスニペット内の移動は`Tab`／`Shift-Tab`です。従来の`Ctrl-B`／`Ctrl-F`による補完ドキュメントのスクロールは割り当てていません。

`:`のコマンド・パスと、`/`／`?`の検索語は標準の候補メニューを自動表示します。`Tab`／`Shift-Tab`で選択します。補完設定は`lua/base/completion.lua`で管理します。

LSP進捗は標準の`vim.lsp.status()`でステータスラインに表示し、最後の更新から2秒後に消します。Fidgetのフローティング表示は使用しません。現在行のGit履歴はGitsignsで行末に表示し、`:Gitsigns toggle_current_line_blame`で切り替えられます。

### Neovimのファイルサイドバー

`Space` → `j`でOilを左端に幅30列のサイドバーとして開閉します。Oil内で`Enter`を押すと、ディレクトリはその場で移動し、ファイルは右隣の編集ウィンドウに開きます。右側に編集ウィンドウがない場合は、新しく右側に分割して開きます。

### NeovimのMarkdown表示

Markdownは編集とタスク管理を優先した表示です。見出しは`#`の数と色で階層を区別し、H1・H2には文字幅だけの控えめな背景を付けます。コードは内容幅に合わせた背景、表は角丸罫線で整理し、引用・注意書きも色と縦線で区別します。

チェック欄は幅を変えずに`[ ]`を黄色、`[x]`を緑で表示します。完了済みの本文は少し落ち着いた色にし、取り消し線は付けません。現在行は背景と行番号で強調し、その行だけ元のMarkdownを表示するため、`- [ ]`のどの文字にカーソルがあるか確認できます。

通常・コマンドライン・挿入モードで周囲の文書を描画し、入力中も現在行だけ原文を表示します。行番号を残し、空白記号を隠します。日本語の長いタスクでチェック欄だけが前の行に取り残されないよう、画面幅で折り返し、折り返した部分も同じ背景で強調します。英単語も画面端で分割されます。選択モードでは全文を元の編集表示に戻し、`:RenderMarkdown toggle`でも装飾を切り替えられます。元のファイル内容は変更しません。

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

`setup.sh`はHomebrewの既存パッケージを通常アップグレードしません。不足するパッケージと推移依存は、GitHub Packagesに7日以上前に登録された固定のOCI索引から、OS・CPUに合うbottleを選び、SHA256を確認して導入します。Intel MacとmacOS Sonomaでは `packages/homebrew-bottles-intel.json` の対応版を優先します。これらのMacのOpenSSLは3.5 LTSの公式ソースを自動ビルドします。Homebrew 7.0.14以降でソースビルドや中断後の再処理が必要なときは、検証済みレシピをハッシュ別のローカルtap `dotfiles-local/verified-…` に保存します。対応する検証済みの配布物がない場合は対象名を表示して停止します。日常の更新には`pkgupd`を使います。

`pkgupd`は更新候補を検出し、**実際に取得する配布物の信頼できる公開日時から7日**経過したものだけを自動更新します。ローカルの初回検出から数える方式は廃止しました。古い`homebrew.tsv`は参照せず、削除もしません。

```sh
pkgupd
```

Homebrewの取得処理は`scripts/homebrew_release_age.py`、共通の7日判定は`scripts/release_age.py`です。取得できない日時は`published_at=null`とし、候補名・バージョン・日時不明の理由・手動確認が必要なことを標準エラーへ表示します。何日待っても不明を既知へ変換せず、Gitのコミット日付等で推定しません。通知はターミナル出力で行い、外部メッセージ送信はありません。

現時点で自動更新できるのは、公式caskのうち、GitHubの変更不能なRelease assetを直接取得し、公開日時とSHA256が一致し、別パッケージへの依存や自己更新がないものです。Formulaのbottle・ビルドやその他の配布元は、配布物の公開日時を証明する取得処理がないため`null`として保留します。上流ソースの古い公開日を、新しいbottleの公開日として流用しません。必要な更新は、表示された対象の公式公開情報・変更内容を確認して個別に手動適用してください。

Ubuntu/DebianのAPTシステム・セキュリティ更新は遅延させません。Homebrewが失敗してもAPTの処理は試み、どちらかが失敗すれば非ゼロで終了します。Homebrewだけを処理する場合は`pkgupd --homebrew-only`です。日時不明による保留は更新処理の障害とは区別し、候補を表示して正常終了します。`PKGUPD_COOLDOWN_DAYS`や`PKGUPD_NOW_EPOCH`による待機短縮・時刻変更は使用しません。

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

Neovimの`.config/nvim/lua/plugins/`は、1プラグインの設定を1つのLuaファイルにまとめています。Mason・oil-gitも専用ファイルで設定し、プラグイン間の読み込み順は`dependencies`で指定します。追加設定のない共通ライブラリは、利用側の`dependencies`に参照だけを記載します。

GitHub ActionsでUbuntuとmacOSのセットアップスクリプトを検証します。ローカル検査はセットアップ時にuv経由でインストールされます。pre-commitとPython hookに必要なwheelは `packages/bootstrap-wheels.json` に固定し、PyPIにある各ファイルの公開日時とSHA256を照合してから一時ディレクトリに取得します。インストール時にはこのディレクトリだけをパッケージ取得元として使います。

```sh
./tests/smoke-test.sh
pre-commit run --all-files
```

GitHub Actionsとpre-commit hookの外部コードはコミットSHAに固定しています。検証CIの`GITHUB_TOKEN`にはリポジトリ内容とActions履歴の読み取り権限を付与し、checkout後のGit認証情報も保存しません。依存観測も読み取り権限で実行します。

pre-commitではBetterleaksがステージ済みの変更を走査し、token、APIキー、秘密鍵などの機微情報を検出するとコミットを拒否します。検出結果に機微情報そのものを出力しないよう、redactを有効にしています。CIではpre-commitの回避を考慮し、追跡対象の作業ツリー全体を再走査します。加えて`Scan Secret History`はPR・mainへのPush・週次実行で全履歴を取得し、`betterleaks-history`でPR途中のコミットを含む到達可能な履歴全体を走査します。後続コミットで削除された秘密も対象です。ローカルでは`pre-commit run betterleaks-history --hook-stage manual --all-files`を使います。

スモークテストでは、各CLIの起動、ripgrepとfzfによる検索、隔離したHerdrサーバーの起動・接続・停止、zoxideのデータベース操作、`pkgupd`の候補バージョンと待機期間の判定、Bun・Go・Pythonのコード実行、ヘッドレスNeovim上でのPyright接続、標準補完の候補表示・確定・中止と検索・コマンド・パス補完、標準LSP進捗表示とGitsignsの行履歴、Telescopeの検索・除外・プレビュー・キー操作、Markdownパーサーと`render-markdown.nvim`の初期化を確認します。Neovimの検証とセットアップ用Luaコード内の例外・assert失敗は、非ゼロの終了コードで通知します。意図的な失敗による終了コードの回帰テストと、隔離した一時ディレクトリ上でのバックアップ・GitHub CLI移行・アンインストールのテストも実行します。補完キャッシュ作成後の権限変更、Homebrew／APTそれぞれの失敗、checkoutへの直接参照、旧スナップショットからのリンク切り替え、旧`~/.config`リンク・稼働中ソケット・権限と認証情報の保持、削除済み秘密の履歴検出、公開日時の境界・欠損・未来日時、未公開SHAと古い観測記録の拒否、npm integrityとHomebrew日時不明通知、Neovimのインストール済みコミットとロックファイルの一致も検証します。Herdrの対話UI、GUI表示、GitHub認証は手動確認の対象です。

依存関係のEOL検査は毎週月曜日と関連ファイルを変更するPull Requestで実行します。Homebrew formulaの`deprecated`・`disabled`、Neovim・Sheldon・pre-commit・GitHub Actionsで利用するGitHubリポジトリの`archived`・`disabled`を検出すると失敗します。ローカルでも次のコマンドで実行できます。

```sh
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-eol.sh
```

更新頻度の低さだけではEOLと判定せず、HomebrewとGitHubが提供する明示的なライフサイクル情報だけを失敗条件にします。

### 依存関係の公開後待機ルール

判定対象は「最新版」ではなく、導入する正確な版・SHA・配布物です。信頼できる公開日時から7日経過していれば、このリポジトリで初めて採用する版も即時に候補にできます。新しい版が出ても、固定した候補の待機はリセットしません。共通の日時判定は`scripts/release_age.py`で管理し、各配布元の取得処理から公開日時または`null`を受け取ります。

| 対象 | 判定と証拠 |
| --- | --- |
| Bunのnpm依存（ロック内の直接・間接依存） | npmの`time[version]`と`dist.integrity`をロックのSHA512と照合。独自URL・integrityなしは拒否 |
| Git依存（Actions、pre-commit hook、Neovim、Sheldon、Homebrew installer） | GitHubの変更不能なReleaseの`published_at`とタグの解決先SHAが固定SHAと一致すれば、その公開日時から7日 |
| 公開日時とSHAの対応を証明できないGit依存 | 公開リポジトリの実在コミットとdefault branch履歴への到達可能性を確認した初回観測から7日 |
| pre-commit本体 | PyPIの固定版の配布ファイル公開日時。後から追加された配布ファイルも考慮し、yanked・配布なしは拒否 |
| Homebrewの自動更新 | 上記「パッケージ更新」を参照。日時不明は`published_at=null`として通知し、保留 |

GitHub Releaseの`created_at`、Gitのauthor/committer/tagger日時は公開日時として使いません。変更可能なタグとReleaseの古い日付だけでは、現在のコードが以前から公開されていた証明にならないため、実物確認付き観測へ回します。Releaseのないfzf-lua等もこの補助方式です。ネットワーク・APIの失敗を「7日経過済み」として扱いません。

依存関係の観測はmain専用の `Observe Dependency Versions` が行います。mainと公開PRの宣言をデータとして読み、公開リポジトリのdefault branchから到達できるSHAとリポジトリIDを検証します。検証できた組み合わせをActionsのジョブに記録し、GitHubが付与したジョブ完了時刻から7日を数えます。検査時にも依存先の公開状態、SHA、リポジトリID、観測元workflow、実行ブランチとmain履歴への到達可能性を照合します。Actionsの観測履歴が失われた場合は再観測が必要です。

移行承認の対象は固定コミット `a83ade427f8c29ca2399615e5f74a112362f5cdb` にあるGit依存だけです。旧観測ブランチは判定・更新の対象外です。観測はmainへのPush時、6時間ごとの定期実行、mainからの手動実行で行います。

セットアップはパッケージ導入・設定配備より先に管理対象のGit/npm/PyPI検査を実行し、失敗なら停止します。CIの完全セットアップも同じ入口を使います。秘密情報履歴CIもhookの導入前に検査します。APIトークンはセットアップの検査子プロセスにだけ渡し、依存のインストール処理には引き継ぎません。GitHub API制限に達する場合は、`gh auth login`済みの環境または検査用の`GITHUB_TOKEN`を利用してください。

初回セットアップのHomebrew用ロックは `packages/homebrew-bottles.json` です。更新PRのCIは公式レジストリのパッケージ版ID、登録日時、索引のSHA256を照合します。セットアップではロックの日時と索引を検証し、索引に記録されたbottleのSHA256と依存関係を使います。UbuntuでHomebrew自体がない場合は固定リリースからインストールします。Homebrewが指定するportable RubyのSHA256も、公開日時を確認した公式OCI索引と照合します。LuaLS・MarksmanはGitHubのrelease asset ID・SHA256・公開日時と更新日時を確認し、goplsは固定bottle内の単体実行ファイルを使います。APTはOSの署名済みリポジトリとセキュリティ更新方針に従います。すでに端末にあるツールは既存の信頼対象です。

緊急セキュリティ修正は、ユーザーの明示承認を得て`packages/dependency-exceptions.json`へ正確な対象・理由・承認PR URL・期限（最大7日）を記録します。Gitは`owner/repo@完全SHA`、npmは`npm:名前@固定版`、PyPIは`pypi:pre-commit@固定版`をキーとし、値には`reason`、`approval_url`、`expires_at`（タイムゾーン付きISO 8601）を指定します。検査は**main上の承認済みファイルだけ**を参照するため、依存変更PRで追加した自己承認は効きません。例外で省略できるのは待機時間だけで、存在・公開状態・integrityの検証は省略しません。現在の例外は空です。

待機条件だけが未達の候補は、他の検証結果と未達理由を明記したDraft PRとして提案できます。実物観測が必要ならmainのobserverを実行し、表示された期限後に同じSHAでCIを再実行します。待機中は完全セットアップCIが停止することが正常で、成功・導入完了とは報告しません。

```sh
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-cooldown.sh
gh workflow run dependency-observations.yml --ref main
```

## ライセンス

[MIT](LICENSE)
