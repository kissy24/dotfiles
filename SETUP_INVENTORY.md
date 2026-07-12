# `setup.sh` インストール対象一覧

現行の `setup.sh` がインストールするツールと、セットアップ後の処理によって間接的に導入されるプラグイン・Language Serverを整理したものです。

この文書は現状把握を目的としており、刷新案や変更方針はまだ含めていません。

## 直接インストールするもの

| ツール | macOS | Ubuntu | 用途・現在の使われ方 |
| --- | --- | --- | --- |
| Git | Homebrew | apt | バージョン管理。Neovimプラグインの取得にも必要 |
| Starship | Homebrew | 公式インストールスクリプト | Zshのプロンプト表示 |
| Rust / Cargo | Homebrew | rustup | Rust開発環境。現状は主にSheldonのインストールに使用 |
| Lazygit | Homebrew | GitHub Release | GitをTUIで操作。Zshの`lg`エイリアスとNeovimから利用 |
| Node.js | Homebrew | aptで一時導入後、`n stable`で再導入 | JavaScript/TypeScriptランタイム。TypeScript系LSPなどMasonパッケージの実行にも必要 |
| npm | Node.jsに付属 | aptで一時導入 | UbuntuでNode.js管理ツール`n`をインストールするために使用 |
| `n` | インストールしない | npm global | Ubuntuで安定版Node.jsを導入するバージョン管理ツール |
| ripgrep (`rg`) | Homebrew | apt | 高速な全文検索。NeovimのTelescopeがファイル検索とgrepに直接使用 |
| fd | Homebrew | `fd-find` | 高速なファイル検索。現行のリポジトリ設定内では明示的な利用箇所なし |
| GitHub CLI (`gh`) | Homebrew | GitHub公式aptリポジトリ | Issue、Pull Request、認証などのGitHub操作 |
| tmux | Homebrew | apt | ターミナルの画面分割・セッション管理 |
| zoxide | Homebrew | apt | 使用履歴を学習する高速なディレクトリ移動 |
| fzf | Homebrew | apt | 曖昧検索UI。現行のリポジトリ設定内では明示的なキーバインドなどはなし |
| Go | Homebrew | apt | Go開発環境。`gopls`によるGo編集にも対応 |
| Neovim | nightlyのtarball | latestのAppImage | メインエディタ。設定、プラグイン、LSPをまとめて利用 |
| uv | 公式インストールスクリプト | 公式インストールスクリプト | Python本体、仮想環境、依存関係、Python製ツールの管理 |
| Bun | 公式インストールスクリプト | 公式インストールスクリプト | JavaScript/TypeScriptランタイム兼パッケージマネージャー |
| Sheldon | Cargo | Cargo | Zshプラグインマネージャー |

macOSでは、GitからGoまでの主要パッケージをHomebrewで一括インストールします。Neovimとuvは個別にダウンロード・インストールされます。

Ubuntuでは、基本パッケージをaptで導入し、GitHub CLI、Node.js、Neovim、Rust、Starship、Lazygit、uvをそれぞれ異なる方法で追加します。

## Ubuntuのみインストールするビルド・通信系パッケージ

| パッケージ | 用途 |
| --- | --- |
| curl | インストーラーやGitHub Releaseのダウンロード |
| build-essential | C/C++コンパイラ、makeなどの基本ビルド環境 |
| pkg-config | ネイティブライブラリのビルド設定検出 |
| libssl-dev | OpenSSLを使うソフトウェアのコンパイル |

これらは日常的に直接操作するツールというより、Rust/Cargoなどによるビルドを成立させるための基盤です。

## Sheldonが追加するZshプラグイン

`setup.sh`は`cargo install sheldon`でSheldon本体を導入し、`sheldon lock`によって `.config/sheldon/plugins.toml` に定義されたプラグインを取得します。

| プラグイン | 用途 |
| --- | --- |
| zsh-autosuggestions | コマンド履歴をもとに入力候補を薄く表示 |
| zsh-syntax-highlighting | 入力中のコマンドを構文や有効性に応じて色付け |
| zsh-history-substring-search | 入力中の文字列を含むコマンド履歴を検索 |

## Neovimが追加するプラグイン

`setup.sh`は次のコマンドを実行します。

```sh
nvim --headless -c 'Lazy sync' -c 'qa'
```

これにより、Lazy.nvim本体とNeovim設定に定義された以下のプラグインが導入されます。

| 分類 | プラグイン | 用途 |
| --- | --- | --- |
| 管理 | lazy.nvim | Neovimプラグインのインストール、更新、遅延ロード |
| 外観 | catppuccin | Mochaカラースキーム |
| 外観 | lualine.nvim | ステータスライン |
| 外観 | nvim-web-devicons | ファイル種別アイコン |
| Git | gitsigns.nvim | 変更行、追加、削除などを画面端に表示 |
| Git | lazygit.nvim | NeovimからLazygitを起動 |
| Git | git-blame.nvim | 行ごとのコミット日時、作者などを表示 |
| Git | oil-git.nvim | Oil上でGitの状態を表示 |
| 検索 | telescope.nvim | ファイル、文字列、バッファ、ヘルプの曖昧検索 |
| ファイル | oil.nvim | ディレクトリを編集可能なバッファとして操作 |
| 共通部品 | plenary.nvim | TelescopeやLazygitプラグインなどが利用するLuaライブラリ |
| LSP | nvim-lspconfig | Language ServerのNeovim設定 |
| LSP | mason.nvim | LSPなどの外部開発ツールを管理 |
| LSP | mason-lspconfig.nvim | Masonとnvim-lspconfigを連携 |
| 補完 | nvim-cmp | 入力補完エンジン |
| 補完 | cmp-nvim-lsp | LSPから補完候補を取得 |
| 補完 | cmp-buffer | 開いているバッファから補完候補を取得 |
| 補完 | cmp-path | ファイルパスを補完 |
| 補完 | cmp-cmdline | Neovimのコマンドラインを補完 |
| 表示 | fidget.nvim | LSPの処理進捗を表示 |

## Masonが追加するLanguage Server

Neovim設定の`mason-lspconfig`にある`ensure_installed`によって、以下のLanguage Serverが追加取得されます。

| Masonでの名前 | 対象言語・形式 |
| --- | --- |
| lua_ls | Lua |
| ts_ls | TypeScript / JavaScript |
| html | HTML |
| cssls | CSS |
| jsonls | JSON |
| marksman | Markdown |
| pyright | Python |
| gopls | Go |

これらは`setup.sh`に名前が直接書かれていませんが、Neovimプラグイン同期後の設定読み込みによってインストールされるため、実質的なセットアップ対象です。

## インストールせず、設定だけ管理しているもの

以下は設定ファイルへのシンボリックリンクを作成しますが、アプリケーション本体は`setup.sh`でインストールしません。

| 対象 | 状態 |
| --- | --- |
| Zsh | 事前インストールが必要 |
| WezTerm | 事前インストールが必要 |
| HackGen Console NF | WezTerm設定が要求するフォント。別途インストールが必要 |
| pre-commit | 設定ファイルは存在するが、本体もGit hooksも`setup.sh`では導入しない |

## 作成するシンボリックリンク

| リポジトリ内の設定 | リンク先 |
| --- | --- |
| `.zshrc` | `~/.zshrc` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.config/starship.toml` | `~/.config/starship.toml` |
| `.config/nvim` | `~/.config/nvim` |
| `.config/wezterm` | `~/.config/wezterm` |
| `.config/sheldon` | `~/.config/sheldon` |
| `.config/lazygit` | `~/.config/lazygit` |
| `.config/gh` | `~/.config/gh` |

リンク先に既存のファイルまたはディレクトリがある場合は、同じ場所の`.bak`へ移動してからリンクを作成します。

## 現状から見える確認ポイント

以下は変更案ではなく、今後の見直し時に判断が必要になりそうな点です。

- Rust一式の主用途がSheldonのビルドだけでよいか。
- Node.jsとBunを併用する必要があるか、それぞれの担当範囲をどうするか。
- `fd`と`fzf`を今後使うのか。現在の設定内には直接の利用箇所が見当たらない。
- Go開発環境と`gopls`が常に必要か、用途別の任意インストールにするか。
- macOS版Neovimがnightly固定でよいか。
- macOS版NeovimのダウンロードがIntel用`x86_64`に固定されている。
- Ubuntu版NeovimとLazygitも`x86_64`に固定されている。
- uv、Rust、Starship、Bunで`curl | sh`形式のインストールを利用してよいか。
- 全ツールを無条件に導入するのか、「必須」「開発言語別」「任意」などに分割するか。
- 既存設定のバックアップが単一の`.bak`のみで、再実行時の衝突をどう扱うか。
- `pre-commit`設定は存在するが、本体のインストール経路がない状態でよいか。
- Zsh、WezTerm、HackGen Console NFを事前準備のままにするか、セットアップ対象に含めるか。
