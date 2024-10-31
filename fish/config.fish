# uv completion
if type -q uv
    uv generate-shell-completion fish | source
end
# starship 
starship init fish | source
