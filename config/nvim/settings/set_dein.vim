let s:DEIN = g:CONFIG . '/dein'
let s:DEIN_DIR = s:DEIN . '/repos/github.com/Shougo/dein.vim'

if !isdirectory(s:DEIN_DIR)
  call system('git clone https://github.com/Shougo/dein.vim ' . shellescape(s:DEIN_DIR))
endif

execute 'set runtimepath^=' . s:DEIN_DIR

if !dein#load_state(s:DEIN)
  finish
endif

let s:TOML_DIR = g:SETTINGS . '/dein'
let s:DEIN_TOML = s:TOML_DIR . '/dein.toml'
let s:DEIN_LAZY_TOML = s:TOML_DIR . '/dein_lazy.toml'

call dein#begin(s:DEIN, [expand('<sfile>'), s:DEIN_TOML, s:DEIN_LAZY_TOML])
call dein#load_toml(s:DEIN_TOML, {'lazy': 0})
call dein#load_toml(s:DEIN_LAZY_TOML, {'lazy': 1})
call dein#end()
call dein#save_state()

if dein#check_install()
  call dein#install()
endif