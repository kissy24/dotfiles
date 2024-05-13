#!/bin/bash

BASEDIR=$HOME/workspace/dotfiles
CONFDIR=$HOME/.config
NVIM=$CONFDIR/nvim

# Ubuntu向けのNeovimインストール関数
install_neovim_ubuntu() {
    echo "Ubuntuディストリビューションを検出しました。"

    # Neovimがインストールされているか確認
    if ! command -v nvim &> /dev/null; then
        # Neovimがインストールされていない場合は、インストールを試みる
        echo "Neovimが見つかりません。Neovimをインストールします..."
        sudo apt update
        sudo apt install neovim -y
        if [ $? -eq 0 ]; then
            echo "Neovimのインストールが完了しました。"
        else
            echo "Neovimのインストール中にエラーが発生しました。"
            exit 1
        fi
    else
        echo "Neovimは既にインストールされています。"
    fi
}

# Manjaro向けのNeovimインストール関数
install_neovim_manjaro() {
    echo "Manjaroディストリビューションを検出しました。"

    # Neovimがインストールされているか確認
    if ! command -v nvim &> /dev/null; then
        # Neovimがインストールされていない場合は、インストールを試みる
        echo "Neovimが見つかりません。Neovimをインストールします..."
        sudo pacman -Syu --noconfirm neovim
        if [ $? -eq 0 ]; then
            echo "Neovimのインストールが完了しました。"
        else
            echo "Neovimのインストール中にエラーが発生しました。"
            exit 1
        fi
    else
        echo "Neovimは既にインストールされています。"
    fi
}

# .configとnvimの存在確認
check_folder() {
    # .configフォルダが存在するか確認
    if [ ! -d $CONFDIR ]; then
        echo "~/.config フォルダが見つかりません。作成します..."
        mkdir -p $CONFDIR
        if [ $? -eq 0 ]; then
            echo "$CONFDIR フォルダの作成が完了しました。"
        else
            echo "エラー: $CONFDIR フォルダの作成中に問題が発生しました。"
            exit 1
        fi
    else
        echo "$CONFDIR フォルダは既に存在します。"
    fi

    cd $CONFDIR
    # nvimのシンボリックリンクが存在するか確認
    if [ -L $NVIM ]; then
        echo "シンボリックリンク $NVIM は存在します。"
        # シンボリックリンクを削除
        unlink $NVIM
        if [ $? -eq 0 ]; then
            echo "シンボリックリンク $NVIM を削除しました。"
        else
            echo "エラー: シンボリックリンク $NVIM の削除中にエラーが発生しました。"
            exit 1
        fi
    else
        echo "エラー: シンボリックリンク $NVIM が存在しません。"
    fi
    # nvimフォルダが存在するか確認
    if [ -d $NVIM] ; then
        # フォルダが存在する場合は削除
        rm -rf "nvim"
        echo "nvimフォルダを削除しました。"
    else
        echo "nvimフォルダは存在しません。"
    fi
}


# ディストリビューションを判別して適切な関数を呼び出す
main() {
    if [ -f /etc/os-release ]; then
        distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
        case "$distro" in
            "Ubuntu")
                install_neovim_ubuntu
                ;;
            "Manjaro Linux")
                install_neovim_manjaro
                ;;
            *)
                echo "サポートされていないディストリビューションです。"
                exit 1
                ;;
        esac
    else
        echo "OS情報を取得できませんでした。"
        exit 1
    fi
    check_folder
    ln -s $BASEDIR/nvim $NVIM
    if [ -L $NVIM ]; then
        echo "シンボリックリンク $NVIM は正常に貼り付けできました。"
    else
        echo "エラー: シンボリックリンク $NVIM の貼り付けができませんでした。"
    fi
}

main
