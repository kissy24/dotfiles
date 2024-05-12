#!/bin/bash

# Ubuntu向けのNeovimインストール関数
install_neovim_ubuntu() {
    echo "Ubuntuディストリビューションを検出しました。"

    # Neovimがインストールされているか確認
    if ! command -v nvim &> /dev/null; then
        # Neovimがインストールされていない場合は、インストールを試みる
        echo "Neovimが見つかりません。Neovimをインストールします..."
        # sudo apt update
        # sudo apt install neovim -y
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
        # sudo pacman -Syu --noconfirm neovim
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
}

main

BASEDIR=$HOME/dotfiles
CONFDIR=$HOME/.config

cd $CONFDIR
NVIM=$CONFDIR/nvim
# nvimフォルダが存在するか確認
if [ -d $NVIM] ; then
    # フォルダが存在する場合は削除
    # rm -rf $NVIM
    echo "nvimフォルダを削除しました。"
else
    echo "nvimフォルダは存在しません。"
fi
