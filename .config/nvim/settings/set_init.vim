" 不要なデフォルトプラグインを無効化
let g:loaded_gzip               = 1
let g:loaded_tar                = 1
let g:loaded_tarPlugin          = 1
let g:loaded_zip                = 1
let g:loaded_zipPlugin          = 1
let g:loaded_rrhelper           = 1
let g:loaded_vimball            = 1
let g:loaded_vimballPlugin      = 1
let g:loaded_getscript          = 1
let g:loaded_getscriptPlugin    = 1
let g:loaded_netrw              = 1
let g:loaded_netrwPlugin        = 1
let g:loaded_netrwSettings      = 1
let g:loaded_netrwFileHandlers  = 1
" タイトルを表示
set title
" 行を強調表示
set cursorline
" 行番号を表示
set number
" カーソルの位置表示
set ruler
" 不可視文字を表示
set list
" 行の折返しをしない
set nowrap
" tabを4space調整
set expandtab
set smarttab
set shiftround
set shiftwidth=4
" 前の行のindentを引き継ぐ
set autoindent
" ブロックごとに自動indent
set smartindent
" swap,backupは生成しない
set noswapfile
set nowritebackup
set nobackup
" 検索するときに大文字小文字を区別しない
set ignorecase
" 小文字で検索すると大文字と小文字を無視して検索
set smartcase
" 検索ワードの最初の文字を入力した時点で検索が開始
set incsearch
" 検索がファイル末尾まで進んだら、ファイル先頭から再び検索
set wrapscan
" 検索結果をハイライト表示
set hlsearch
" split時のnew fileの位置
set splitbelow
set splitright
" mode表示を無効化(StatusLineが代替)
set noshowmode
" 常にTab,Statusを表示
set laststatus=2
set showtabline=2
" 保存無視
set hidden
" コマンド・検索パターンの履歴
set history=1000
" クリップボード追加オプション
set clipboard+=unnamedplus
