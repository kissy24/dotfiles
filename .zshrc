# ~/.zshrc

# 履歴ファイルの設定
HISTFILE=~/.zsh_history
HISTSIZE=50000        # メモリ上の履歴数
SAVEHIST=50000        # ファイルに保存する履歴数

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

eval "$(starship init zsh)"
. "$HOME/.local/bin/env"
. "$HOME/.cargo/env"

eval "$(sheldon source)"
