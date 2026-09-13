# Ubuntuの/etc/zsh/zshrcによるcompinitを無効化する。
# 補完は管理対象の.zshrcで生成済みdumpを使って初期化する。
skip_global_compinit=1

# rustupが作成するユーザー単位のCargo環境を、存在する場合だけ引き継ぐ。
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
