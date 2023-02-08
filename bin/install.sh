cat <<EOS
┌──────────────────────────┐
│                          │
│ Install Kissy24 Settings │
│                          │
└──────────────────────────┘
EOS

set -u

BASEDIR=$HOME/dotfiles
FISH=$HOME/.config/fish
NVIM=$HOME/.config/nvim

cd $BASEDIR

if [ -d $FISH] ; then
rm $FISH
mkdir $FISH
fi
ln -s $BASEDIR/fish $FISH
printf "Fish Done\n"

if [ -d $NVIM] ; then
rm $NVIM
mkdir $NVIM
fi
ln -s $BASEDIR/nvim $NVIM
printf "Neovim Done\n"