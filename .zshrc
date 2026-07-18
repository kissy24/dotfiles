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

# Setopt
setopt HIST_IGNORE_ALL_DUPS   # 履歴中の重複を削除
setopt HIST_SAVE_NO_DUPS      # 重複するコマンドは保存しない
setopt HIST_FIND_NO_DUPS      # 履歴検索で重複を表示しない
setopt SHARE_HISTORY          # 複数のzshセッション間で履歴を共有
setopt HIST_REDUCE_BLANKS     # 余分な空白を削除
setopt HIST_VERIFY            # 履歴展開時に確認
setopt EXTENDED_HISTORY       # 実行時間も記録
DIRSTACKSIZE=100
setopt AUTO_CD          # ディレクトリ名だけで移動
setopt AUTO_PUSHD       # cd で自動的に pushd
setopt PUSHD_IGNORE_DUPS # 重複するディレクトリをスタックに積まない

# Alias
alias d="dirs -v"
alias ls="ls -GF"
alias ll="ls -alFhG"
alias la="ls -AFG"
alias l="ls -lFh"
alias lg="lazygit"
alias hr="herdr"

# カレントディレクトリまたは指定したディレクトリをHerdr Workspaceとして開く
hrw() {
    if (( $# > 2 )); then
        print -u2 "usage: hrw [directory] [label]"
        return 2
    fi

    local workspace_dir="${1:-$PWD}"
    if [[ ! -d "$workspace_dir" ]]; then
        print -u2 "hrw: directory not found: $workspace_dir"
        return 1
    fi

    workspace_dir="${workspace_dir:A}"
    local workspace_label="${2:-${workspace_dir:t}}"
    herdr workspace create \
        --cwd "$workspace_dir" \
        --label "$workspace_label" \
        --focus
}


# Vim Mode
export KEYTIMEOUT=20
bindkey -v
bindkey -M viins 'jj' vi-cmd-mode

# パッケージマネージャー
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    alias pkgupd='brew update && brew upgrade && brew cleanup && sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    alias pkgupd='brew update && brew upgrade && brew cleanup'
fi

# ユーザー単位でインストールしたCLI
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"


# uv completion
if command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# Homebrew (Apple Silicon, Intel macOS, Linux)
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Herdr completion
if command -v herdr &> /dev/null; then
    eval "$(herdr completion zsh)"
fi

# fzf標準連携 (Ctrl-R: 履歴、Ctrl-T: ファイル、Alt-C: ディレクトリ)
source <(fzf --zsh)

# init plugins
eval "$(starship init zsh)"
eval "$(sheldon source)"
eval "$(zoxide init zsh)"

# マシン固有の設定（Git・setup.shの管理対象外）
if [[ -r "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
