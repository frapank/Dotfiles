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

# -- TMUX
if [ -n "$PS1" ]; then
  if command -v tmux >/dev/null 2>&1; then
    if [ -z "$TMUX" ]; then
      tmux attach-session -t main 2>/dev/null || tmux new-session -s main
    fi
  fi
fi

# -- OTHER / PATHS
