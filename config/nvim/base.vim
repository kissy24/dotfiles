if &compatible
  set nocompatible
endif

augroup MyAutoCmd
  autocmd!
augroup END

let g:CONFIG = empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME
let g:SETTINGS = g:CONFIG . '/nvim/settings/'

function! s:source_vim(path) abort
  let abspath = resolve(expand(g:SETTINGS . a:path))
  execute 'source' fnameescape(abspath)
endfunction

filetype plugin indent on
syntax on

call s:source_vim('set_init.vim')
call s:source_vim('set_map.vim')
call s:source_vim('set_dein.vim')
