#!/bin/bash

BASEDIR=$HOME/dotfiles
CONFDIR=$HOME/.config
NVIM=$CONFDIR/nvim

# Neovimインストール関数
install_neovim() {
    echo "Neovimのインストールを確認しています..."

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
        rm -rf "nvim"
        echo "nvimフォルダを削除しました。"
    else
        echo "nvimフォルダは存在しません。"
    fi
}


main() {
    install_neovim
    check_folder
    ln -s $BASEDIR/nvim $NVIM
    if [ -L $NVIM ]; then
        echo "シンボリックリンク $NVIM は正常に貼り付けできました。"
    else
        echo "エラー: シンボリックリンク $NVIM の貼り付けができませんでした。"
    fi
}

main
