# uv completion
if type -q uv
    uv generate-shell-completion fish | source
end
# mac os
if test (uname) = "Darwin"
    eval (/opt/homebrew/bin/brew shellenv)
end
# starship 
starship init fish | source

# bun
if test -x "$HOME/.bun"
    set --export BUN_INSTALL "$HOME/.bun"
    set --export PATH $BUN_INSTALL/bin $PATH
end
