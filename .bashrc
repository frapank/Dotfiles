# -- UTILS
alias nvim='nvim -u ~/.nvimrc.lua'
alias vim='/usr/local/bin/vim'
alias ls='ls --color=auto -h --group-directories-first'

# -- DESIGN
GREEN="\[\e[32m\]"
RED="\[\e[31m\]"
NORMAL="\[\e[0m\]"

__set_bash_prompt() {
  local status=$?
  local symbol="$"
  [ $status -ne 0 ] && symbol="${RED}\$${NORMAL}"
  PS1="${symbol} \W: "
}

PROMPT_COMMAND="__set_bash_prompt"

# -- TMUX
if [[ -n "$PS1" && -z "$TMUX" && "$TERM" != "dumb" ]]; then
  command -v tmux >/dev/null &&
    tmux attach -t main 2>/dev/null || tmux new -s main
fi
