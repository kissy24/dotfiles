# `setup.sh` インストール対象一覧

刷新後の`setup.sh`が導入するツールと、その用途をまとめたものです。すべての依存はコードまたは設定ファイルに列挙されています。

## kissy24からの要求と対応

| 要求 | 対応 |
| --- | --- |
| UbuntuとmacOSを基本的にHomebrewで統一 | 共通ツールを単一の`Brewfile`から導入 |
| 全ライブラリをコードか設定へ列挙 | Brewfile、apt一覧、Bun manifest、Mason、Sheldonを情報源にする |
| Ubuntu固有設定にはaptを利用 | Homebrew導入前提だけを`packages/apt.txt`からaptで導入 |
| curlやCargoでの導入を最小化 | curlはUbuntuへのHomebrew導入時だけ使用し、Cargo/Rustは廃止 |
| Node.js/npm/`n`を廃止してBunへ統一 | npm由来LSPもBunでインストール・実行 |
| fdを廃止し、fzfを活用 | fdを削除し、fzf公式Zsh連携を有効化 |
| Goを必須にする | `Brewfile`へGoを収録して常に導入 |
| Neovimをlatest安定版にする | Homebrewの安定版Formulaから導入 |
| 構成を過度に分割しない | 単一の`Brewfile`とセットアップ経路に統一 |
| 既存設定を上書きまたは何もしない | 既定はスキップ、`--force`指定時だけ置換 |
| uv経由でpre-commitを必須化 | `uv tool install pre-commit`とGit hooks設定を実行 |
| Zsh、WezTerm、フォントは前提のまま | セットアップ対象外を維持 |

## Homebrewパッケージ

宣言元は単一の`Brewfile`です。

| ツール | 用途 |
| --- | --- |
| Git | バージョン管理とNeovimプラグイン取得 |
| Starship | Zshプロンプト |
| Sheldon | Zshプラグイン管理。Homebrew版を使うためRust/Cargoは不要 |
| Lazygit | GitのTUI操作とNeovim連携 |
| ripgrep | 高速全文検索とTelescopeの検索バックエンド |
| GitHub CLI | GitHubのIssue、Pull Request、認証操作 |
| tmux | ターミナルの画面分割とセッション管理 |
| zoxide | 使用履歴に基づくディレクトリ移動 |
| fzf | Zshの履歴、ファイル、ディレクトリ、補完の曖昧検索 |
| Neovim | 安定版のメインエディタ |
| Bun | JavaScript/TypeScriptランタイム、パッケージ管理、npm由来LSPの実行 |
| uv | Python環境とPython製CLIの管理 |
| Go | Go開発環境 |

uvは追加でpre-commitをtool installし、pre-commitとcommit-msgのGit hooksを設定します。

## Ubuntu固有のaptパッケージ

宣言元は`packages/apt.txt`です。

| パッケージ | 用途 |
| --- | --- |
| build-essential | Homebrewが必要とする基本ビルド環境 |
| procps | Homebrewが必要とするプロセス関連ツール |
| curl | Homebrew公式インストーラーの取得 |
| file | Homebrewが必要とするファイル種別判定 |
| git | Homebrew本体とFormulaの取得 |

## Zshプラグイン

`.config/sheldon/plugins.toml`が以下を宣言します。

| プラグイン | 用途 |
| --- | --- |
| zsh-autosuggestions | 履歴をもとに入力候補を表示 |
| zsh-syntax-highlighting | コマンド入力を構文に応じて色付け |
| zsh-history-substring-search | 入力文字列を含む履歴を検索 |

## Neovimプラグイン

Lazy.nvimがカラースキーム、ステータスライン、Git表示、Lazygit連携、Telescope、Oil、LSP、補完、進捗表示の各プラグインを管理します。具体的な一覧は`.config/nvim/lua/plugins`が情報源です。

## Language Server

| 管理方法 | 対象 |
| --- | --- |
| Mason | Lua (`lua_ls`)、Markdown (`marksman`)、Go (`gopls`) |
| Bun manifest | TypeScript/JavaScript、HTML、CSS、JSON、Python (`pyright`) |

Bun管理対象は`packages/bun-lsp/package.json`と`bun.lock`で固定し、`~/.local/share/dotfiles-lsp`へ導入します。Neovimは各サーバーを`bun`で明示的に起動するため、Node.jsコマンドは不要です。

## セットアップ対象外

- Zsh
- WezTerm
- HackGen Console NF

これらは事前にインストールされていることを前提とします。

## 安全動作

- `setup.sh`は`Brewfile`にある全ツールを導入します。
- 既存dotfileは既定で変更しません。
- `--force`指定時だけ既存パスを削除してシンボリックリンクへ置換します。
- `uninstall.sh`は既定で、このリポジトリを指すリンクだけを削除します。
- パッケージ削除は`--packages`を明示し、確認に同意した場合だけ実行します。
