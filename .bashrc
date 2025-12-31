# -- UTILS
alias nvim='nvim -u ~/.nvimrc.lua'
alias vim='/usr/local/bin/vim'
alias ls='ls -h --group-directories-first --indicator-style=classify'

# -- DESIGN
__set_bash_prompt() {
  local s=$? p='$'
  (( s )) && p='\[\e[31m\]$\[\e[0m\]'
  PS1="$p \W: "
}
PROMPT_COMMAND="__set_bash_prompt"

# -- TMUX
if [[ $PS1 && -z $TMUX && $TERM != dumb ]] && command -v tmux >/dev/null; then
  tmux attach -t main 2>/dev/null || tmux new -s main
fi
