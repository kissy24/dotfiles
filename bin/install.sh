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
fi
mkdir -p $FISH
ln -s $BASEDIR/fish $FISH
printf "Fish Done\n"

if [ -d $NVIM] ; then
rm $NVIM
fi
mkdir -p $NVIM
ln -s $BASEDIR/nvim $NVIM
printf "Neovim Done\n"