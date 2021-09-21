" vi互換動作を切る(多分いらない)
if &compatible
  set nocompatible
endif

" 一部のプラグインの呼び出しをグループ化
augroup MyAutoCmd
  autocmd!
augroup END

" XDG_CONFIG_HOME の設定
let g:CONFIG = empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME
let g:SETTINGS = g:CONFIG . '/nvim/settings/'

" settingsフォルダのvimscriptを実行する
function! s:source_vim(path) abort
  let abspath = resolve(expand(g:SETTINGS . a:path))
  execute 'source' fnameescape(abspath)
endfunction

" インデントとシンタックス
filetype plugin indent on
syntax on

" 各vimscriptを呼び出す
call s:source_vim('set_init.vim')
call s:source_vim('set_map.vim')
call s:source_vim('set_dein.vim')
