" pocket-vimrc
" https://github.com/kissy24/pocket-vimrc

" ---Options---

" Disable unwanted default plug-ins
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

" Display
set title
set cursorline
set number
set list
set nowrap
set noshowmode

" Tab
set expandtab
set smarttab
set shiftround
set shiftwidth=4
set showtabline=2

" Indent
set autoindent
set smartindent

" Swap, Backup
set noswapfile
set nowritebackup
set nobackup

" Search
set ignorecase
set smartcase
set incsearch
set wrapscan
set hlsearch

" Split
set splitbelow
set splitright

" Other
set hidden
set history=1000
set clipboard+=unnamedplus

" ---Mapping---

" Exit insert mode with jj
inoremap <silent> jj <ESC>
inoremap <silent> っj <ESC>

" Moving the pane
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Split
nnoremap ss :split<Return><C-w>w
nnoremap sv :vsplit<Return><C-w>w

" Use yank register
nnoremap pp \"0p
nnoremap PP \"0P
