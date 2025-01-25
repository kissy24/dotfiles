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
