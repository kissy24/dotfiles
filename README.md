# Dotfiles

[![License: MIT](https://img.shields.io/github/license/kissy24/dotfiles)](LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/kissy24/dotfiles)

macOSおよびUbuntu/WSL向けの個人開発環境です。共通のコマンドラインツールはHomebrewでインストールし、セットアップスクリプトが設定ファイルを`$HOME`以下へシンボリックリンクします。

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

既存のdotfilesはデフォルトでは変更せずにスキップします。管理対象のシンボリックリンクへ置き換える場合は`./setup.sh --force`を使います。置換対象のパスは削除されるため、実行前に内容を確認してください。

パッケージの宣言は`Brewfile`、`packages/apt.txt`、`packages/bun-lsp/package.json`にあります。SheldonとMasonの依存関係は、それぞれの設定ファイルで管理します。

## 導入する環境

- Zsh向けのStarship、Sheldon、zoxide、fzf連携
- tmuxによるセッション・ペイン管理
- Lazy.nvim、補完、Telescope、Oil、Git連携、LSP、Markdownレンダリングを備えた安定版Neovim
- Bunに統一したJavaScript/TypeScript環境（Node.jsとnpmはインストールしません）
- goplsを含むGo開発環境
- uvによるpre-commitとPythonツール管理

fzfのZsh連携では、Ctrl-Rによる履歴検索、Ctrl-Tによるファイル選択、Alt-Cによるディレクトリ選択、曖昧補完を利用できます。

## 管理する設定

`setup.sh`は`.zshrc`、`.tmux.conf`、Starship、Neovim、WezTerm、Sheldon、Lazygit、GitHub CLIの設定へシンボリックリンクを作成します。

NeovimプラグインはLazy.nvimで同期します。Markdownを開くと`render-markdown.nvim`が読み込まれ、Neovim標準の`markdown`と`markdown_inline`パーサーで表示を拡張します。Lua、Markdown、GoのLanguage ServerはMasonで管理し、TypeScript/JavaScript、HTML、CSS、JSON、PythonのLanguage Serverは追跡対象のBun manifestからインストールしてBunで実行します。

### マシン固有のZsh設定

管理対象の`.zshrc`は、`~/.zshrc.local`が存在する場合に最後に読み込みます。特定のマシンだけで使うエイリアス、環境変数、PATHなどを記述できます。

```sh
touch ~/.zshrc.local
chmod 600 ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

`~/.zshrc.local`は、このリポジトリによる作成、リンク、削除、Git管理の対象外です。共通設定の後に読み込むため、共通のエイリアスや環境変数をマシンごとに上書きできます。

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

GitHub ActionsでUbuntuとmacOSのセットアップスクリプトを検証します。ローカル検査はセットアップ時にuv経由でインストールされます。

```sh
./scripts/smoke-test.sh
pre-commit run --all-files
```

pre-commitではBetterleaksがステージ済みの変更を走査し、token、APIキー、秘密鍵などの機微情報を検出するとコミットを拒否します。検出結果に機微情報そのものを出力しないよう、redactを有効にしています。CIではpre-commitの回避を考慮し、追跡対象の作業ツリー全体を再走査します。

スモークテストでは、各CLIの起動、ripgrepとfzfによる検索、tmuxセッション、zoxideのデータベース操作、Bun・Go・Pythonのコード実行、ヘッドレスNeovim上でのTypeScript Language Server接続、標準Markdownパーサーと`render-markdown.nvim`の初期化を確認します。GUI表示とGitHub認証は手動確認の対象です。

依存関係のEOL検査は毎週月曜日と関連ファイルを変更するPull Requestで実行します。Homebrew formulaの`deprecated`・`disabled`、Neovim・Sheldon・pre-commit・GitHub Actionsで利用するGitHubリポジトリの`archived`・`disabled`を検出すると失敗します。ローカルでも次のコマンドで実行できます。

```sh
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-eol.sh
```

更新頻度の低さだけではEOLと判定せず、HomebrewとGitHubが提供する明示的なライフサイクル情報だけを失敗条件にします。

## ライセンス

[MIT](LICENSE)
