# ~/.zshrc
autoload -Uz compinit && compinit

# 履歴ファイルの設定
HISTFILE=~/.zsh_history
HISTSIZE=10000        # メモリ上の履歴数
SAVEHIST=10000        # ファイルに保存する履歴数

# 大文字小文字を区別しない補完
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
# 補完候補をメニュー形式で表示
zstyle ':completion:*' menu select

# 履歴の重複を削除
setopt HIST_IGNORE_DUPS       # 直前のコマンドと同じなら履歴に追加しない
setopt HIST_IGNORE_ALL_DUPS   # 履歴中の重複を削除
setopt HIST_SAVE_NO_DUPS      # 重複するコマンドは保存しない
setopt HIST_FIND_NO_DUPS      # 履歴検索で重複を表示しない

# 履歴の共有と即座保存
setopt SHARE_HISTORY          # 複数のzshセッション間で履歴を共有
setopt INC_APPEND_HISTORY     # コマンド実行後すぐに履歴に追加

# その他の便利な履歴オプション
setopt HIST_REDUCE_BLANKS     # 余分な空白を削除
setopt HIST_VERIFY            # 履歴展開時に確認
setopt EXTENDED_HISTORY       # 実行時間も記録

# ディレクトリナビゲーション
DIRSTACKSIZE=100
setopt AUTO_CD          # ディレクトリ名だけで移動
setopt AUTO_PUSHD       # cd で自動的に pushd
setopt PUSHD_IGNORE_DUPS # 重複するディレクトリをスタックに積まない

# Alias
alias d='dirs -v'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# パッケージマネージャーの
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    alias pkgupd='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    alias pkgupd='brew update && brew upgrade && brew cleanup'
fi

# envの実行
. "$HOME/.local/bin/env"
. "$HOME/.cargo/env"

# uv completion
if command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# macOS
if [[ "$(uname)" == "Darwin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# bun
if [[ -x "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

# init plugins
eval "$(starship init zsh)"
eval "$(sheldon source)"
eval "$(zoxide init zsh)"
