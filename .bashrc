# -- UTILS
alias ssh='kitten ssh'
alias l='ls'
alias lss='ls'
alias cvim='nvim -u ~/.nvimrc.lua'
alias nvim='nvim -u ~/.nvimrc.lua'
alias vim='/usr/local/bin/vim'
alias f='fzf'
alias gp='git pull'
alias gs='git status'
alias chx='chmod +x'

export LS_OPTIONS='--color=auto -h --group-directories-first'
alias ls="ls $LS_OPTIONS"
alias ll='ls -lh --color=auto --group-directories-first'

# -- DESIGN
GREEN="\[\e[32m\]"
RED="\[\e[31m\]"
NORMAL="\[\e[0m\]"

__set_bash_prompt() {
  local exit_status=$?
  local symbol="$"
  if [ $exit_status -ne 0 ]; then
    symbol="${RED}\$${NORMAL}"
  fi

  local cwd="\W"
  local branch
  PS1="${symbol} ${cwd}: "
}

PROMPT_COMMAND="__set_bash_prompt"

# -- TMUX
if [ -n "$PS1" ]; then
  if command -v tmux >/dev/null 2>&1; then
    if [ -z "$TMUX" ]; then
      tmux attach-session -t main 2>/dev/null || tmux new-session -s main
    fi
  fi
fi

# -- OTHER / PATHS
