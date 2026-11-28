# Load the real prompt without personal settings or unrelated CLI initialization.
HOME=$1
for tool in brew fzf uv herdr sheldon zoxide; do
    functions[$tool]='return 0'
done
source "${0:A:h:h}/.zshrc" || exit 1
setopt ERR_EXIT
COLUMNS=80

check_prompt() {
    [[ $PROMPT == ${~1} ]] || {
        print -ru2 -- "Expected prompt pattern: $1"
        print -ru2 -- "Actual prompt: $PROMPT"
        return 1
    }
}

(( ${precmd_functions[(Ie)_dotfiles_prompt_precmd]} ))
(( ${preexec_functions[(Ie)_dotfiles_prompt_preexec]} ))
cd "$1"
_dotfiles_prompt_precmd
check_prompt '* [0-9][0-9]:[0-9][0-9]*'
[[ $PROMPT != *''* && $PROMPT != *''* ]]

git init -q -b main 'project%F'
cd 'project%F'
_dotfiles_prompt_precmd
check_prompt '*project%%F* main%f*'
[[ $PROMPT != *' *'* && $PROMPT == *$'\n%B%F{#a6e3a1}❯'* ]]

touch changed
_dotfiles_prompt_precmd
check_prompt '* main* \**'
git add changed
_dotfiles_prompt_precmd
check_prompt '* main* \**'
git -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -qm initial
print change > changed
_dotfiles_prompt_precmd
check_prompt '* main* \**'
git restore changed
git switch -q --detach
_dotfiles_prompt_precmd
check_prompt "* $(git rev-parse --short HEAD)%f*"

{ _dotfiles_prompt_preexec; sleep 0.6; false; } || _dotfiles_prompt_precmd
check_prompt '* *s  *'
check_prompt '*%F{#f38ba8}❯*'
COLUMNS=12
_dotfiles_prompt_precmd
[[ $PROMPT != *''* && $PROMPT != *''* ]]
