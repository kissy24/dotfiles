# Dotfiles

macOS・Ubuntu/WSL向けの個人開発環境です。WezTermからHerdrの永続セッションを開き、ZshとNeovimで作業します。共通CLIはHomebrew、JavaScript/TypeScriptはBun、Goはgopls、Pythonツールはuvで管理します。

[日常の操作・パッケージ更新](docs/usage.md) · [設定変更・依存更新・CI](docs/maintenance.md)

## 導入前に確認すること

| 環境 | 自分で用意するもの |
| --- | --- |
| 共通 | Git、Python 3.9以上、インターネット接続。WezTermとフォント `HackGen Console NF` は端末を表示するOSにインストール |
| macOS | Zsh、`brew` を実行できるHomebrew。固定bottleの対象はSonoma以降のIntel／Apple Silicon Mac |
| Ubuntu/Debian | `apt-get` と `sudo` が使えるx86_64／arm64環境。セットアップがZshなどの前提パッケージと、不足しているHomebrewを導入 |
| WSL | 上記Linux環境に加えてWindows版WezTerm。PowerShellの `wsl.exe -l -q` で対象の登録名を確認 |

**既存環境で実行する場合**は、次の変更を確認してください。

- `~/.zshrc`、`~/.zshenv`、`~/.local/bin/pkgupd`、`~/.config` 配下のアプリ設定をcheckoutへ直接リンクします。checkoutを残して使ってください。編集、`git pull`、ブランチ切替はアプリが設定を読み直した時点で日常環境に反映されます。
- 既存の独自設定はスキップします。Neovim・Sheldonが独自設定を使う場合は、そのプラグイン初期化もスキップします。置き換えるには `./setup.sh --force` を選びます。元の設定は同じ親ディレクトリの `<元の名前>.backup-<日時>.<ランダム文字列>/original` に退避します。親がリンクのパスは `--force` でも保持します。[旧管理リンクの移行](docs/maintenance.md#設定の変更と配備)
- セットアップはCLI、言語サーバー、Git hookも導入します。WSLでWindows連携が使える場合は、Windows側の `%USERPROFILE%\.wslconfig` に `guiApplications=false` を設定したファイルをコピーします。反映するとそのWindowsユーザーのWSL 2環境でLinux GUIが使えなくなります。異なる内容の既存ファイルは既定で保持し、`--force` 時は全体を退避して置き換えます。

## インストール

macOSまたはLinux側のシェルで、日常利用する場所にcloneします。

```sh
git clone https://github.com/kissy24/dotfiles.git
cd dotfiles
./setup.sh
```

依存の公開日時検査でGitHub APIの制限に達した場合は、認証済みの `gh` または検査用の `GITHUB_TOKEN` を用意して再実行してください。CLIをすでに導入済みで設定リンクだけ作りたい場合は `./scripts/deploy-config.sh` を使えます。

### Windows版WezTermからWSLを開く

Windows版WezTerm用の設定は手動で読み込ませます。WSLのcheckoutで `wslpath -w "$PWD/.config/wezterm/wezterm.lua"` を実行し、表示されたWindowsパスを控えます。

1. PowerShellで以下を実行し、先ほどのパスを貼り付けます。`.wezterm.lua` がすでにあるとコピーは停止します。その場合は既存ファイルを退避するか、使いたい設定を手動で取り込んでください。

   ```powershell
   $sourceConfig = Read-Host 'WSLで表示されたWindowsパス'
   $targetConfig = Join-Path $env:USERPROFILE '.wezterm.lua'
   [System.IO.File]::Copy($sourceConfig, $targetConfig, $false)
   ```

2. コピーしたファイルの `--distribution` の次にある `Ubuntu-24.04` を、`wsl.exe -l -q` で確認した登録名に合わせます。Windowsで設定ファイルを別途指定している場合は、WezTermが実際に読むファイルにこの設定を取り込んでください。Windows側のコピーには、その後の `git pull` は反映されません。
3. `.wslconfig` の変更を反映する場合は、すべてのWSLセッションの作業を保存してからPowerShellで `wsl.exe --shutdown` を実行します。WSLgを使う場合は先に `.wslconfig` の `guiApplications=false` を削除してください。Windows版WezTermを開き直し、目的のディストリビューションでHerdrが起動すれば設定は有効です。[WezTermの設定ファイル検索順](https://wezterm.org/config/files.html)

## 導入後の確認

端末を開き直して `zsh` を起動し、`command -v herdr nvim pkgupd` でそれぞれのパスを確認します。管理設定を採用した端末では、`readlink ~/.zshrc` がcheckout内の `.zshrc` を指し、`nvim` のノーマルモードで `Space f f` を順に押すとファイル検索が開きます。独自設定を残した端末では、セットアップ出力の `Skipping` で該当項目を確認できます。

## アンインストールと復元

checkoutで `./uninstall.sh` を実行すると、管理対象のリンクを解除します。WSLではWindows側の `.wslconfig` も、管理版と内容が完全に一致すれば削除します。追記・変更したものは保持します。パッケージとバックアップは残ります。

- **以前の設定へ戻す**には、該当するバックアップ内の `original` を元のパスへ移動します。復元先にファイルが残っていれば先に退避してください。複数のバックアップがあれば復元したいものを選びます。Windowsに手動で置いた `.wezterm.lua` も、必要に応じて以前の設定へ戻してください。
- **パッケージも削除する**場合は `./uninstall.sh --packages` を実行します。最初の確認で `y` と答えると、上記の設定に加えて、導入前からあったものを含むBrewfileのインストール済みformula、uv管理のpre-commit、管理用LSPディレクトリを削除します。APTパッケージは残ります。`N` または空の入力で操作全体を中止できます。

[MIT License](LICENSE)
