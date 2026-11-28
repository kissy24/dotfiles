# ~/.zshrc
# ユーザー単位でインストールしたCLI
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"

# Homebrew (Apple Silicon, Intel macOS, Linux)
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv zsh)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv zsh)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# キャッシュを使いつつ、毎回権限を検査して安全でない補完を除外する。
typeset -U fpath
autoload -Uz compinit && compinit -i

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

# 更新後のHerdrと旧サーバーが不整合になった場合に、確認して再起動する
hrr() {
    if (( $# > 1 )); then
        print -u2 "usage: hrr [session]"
        return 2
    fi

    local session_name="${1:-default}"
    if [[ ! -t 0 ]]; then
        print -u2 "hrr: an interactive terminal is required"
        return 1
    fi

    print -u2 "Herdr session '$session_name' の全プロセスを終了して再起動します。"
    if ! read -q "reply?続行しますか? [y/N] "; then
        print
        return 1
    fi
    print

    herdr session stop "$session_name" || return
    exec herdr --session "$session_name"
}

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

# CLI補完はsetup.shで生成したキャッシュを優先する。
zsh_completion_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zsh"
if [[ -r "$zsh_completion_dir/uv.zsh" ]]; then
    source "$zsh_completion_dir/uv.zsh"
elif command -v uv &> /dev/null; then
    eval "$(uv generate-shell-completion zsh)"
fi

# Herdr completion
if [[ -r "$zsh_completion_dir/herdr.zsh" ]]; then
    source "$zsh_completion_dir/herdr.zsh"
elif command -v herdr &> /dev/null; then
    eval "$(herdr completion zsh)"
fi
unset zsh_completion_dir

# fzf標準連携 (Ctrl-R: 履歴、Ctrl-T: ファイル、Alt-C: ディレクトリ)
source <(fzf --zsh)

# 1行目にパス・Git・時刻、2行目に直前の終了状態を表示する。
autoload -Uz add-zsh-hook
zmodload zsh/datetime
unsetopt PROMPT_SUBST PROMPT_BANG

_dotfiles_prompt_preexec() {
    typeset -gF _dotfiles_command_started=$EPOCHREALTIME
}

_dotfiles_prompt_precmd() {
    local last_status=$?
    local path_label=${(%):-%4~} root branch dirty='' elapsed='' marker_color='#a6e3a1'
    local TZ=Asia/Tokyo
    local clock_time
    strftime -s clock_time '%H:%M' "$EPOCHSECONDS"

    if [[ -n ${_dotfiles_command_started:-} ]]; then
        local -F seconds=$(( EPOCHREALTIME - _dotfiles_command_started ))
        if (( seconds >= 0.5 )); then
            printf -v elapsed ' %.1fs  ' "$seconds"
        fi
        unset _dotfiles_command_started
    fi

    root=$(git rev-parse --show-toplevel 2>/dev/null) || root=''
    if [[ -n $root ]]; then
        local relative=${PWD:A}
        relative=${relative#"$root"}
        local repo_path="${root:t}${relative}"
        local -a parts=( "${(@s:/:)repo_path}" )
        path_label=$repo_path
        (( $#parts > 4 )) && path_label=" ${(j:/:)parts[-4,-1]}"
        branch=$(git symbolic-ref --short -q HEAD 2>/dev/null) ||
            branch=$(git rev-parse --short HEAD 2>/dev/null)
        branch=${branch[1,32]}
        [[ -n $(git --no-optional-locks status --porcelain=v1 --untracked-files=normal 2>/dev/null) ]] && dirty=' *'
    fi
    [[ -w . ]] || path_label+=' 󰌾'
    path_label=${(V)path_label}
    branch=${(V)branch}
    local left=$path_label styled="%F{#89b4fa}${path_label//\%/%%}%f"
    if [[ -n $branch ]]; then
        left+="   $branch$dirty"
        styled+="  %F{#f38ba8} ${branch//\%/%%}%f%F{#fab387}${dirty}%f"
    fi
    local clock_text=" $clock_time"
    local right="$elapsed$clock_text"
    local -i gap=$(( COLUMNS - 1 - ${(m)#left} - ${(m)#right} ))
    if (( gap > 0 )); then
        styled+="${(l:$gap:: :)}%F{#f9e2af}${elapsed}%f%F{#a6adc8}${clock_text}%f"
    fi
    (( last_status == 0 )) || marker_color='#f38ba8'
    PROMPT="$styled"$'\n'"%B%F{$marker_color}❯%f%b "
}

add-zsh-hook preexec _dotfiles_prompt_preexec
add-zsh-hook precmd _dotfiles_prompt_precmd

# init plugins
eval "$(sheldon source)"
eval "$(zoxide init zsh)"

# マシン固有の設定（Git・setup.shの管理対象外）
if [[ -r "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
