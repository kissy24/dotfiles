cat <<EOS
┌──────────────────────────┐
│                          │
│ Install Kissy24 Settings │
│                          │
└──────────────────────────┘
EOS
set -u
BASEDIR=$(dirname $0)
cd $BASEDIR
ln -s ~/dotfiles/.fish ~/.config/fish
printf "fish shell Done\n"
ln -s ~/dotfiles/.nvim ~/.config/nvim
printf "Neovim Done\n"